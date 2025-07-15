# frozen_string_literal: true

require "async"
require "open3"
require "json"
require "logger"
require "pathname"
require "timeout"
require_relative "../transport"

module ClaudeSDK
  module Internal
    # Subprocess transport implementation using Claude Code CLI
    #
    # This transport launches the Claude Code CLI as a subprocess and
    # communicates with it via JSON streaming on stdout/stderr.
    #
    # @example
    #   transport = SubprocessCLI.new(
    #     prompt: "Hello Claude",
    #     options: ClaudeCodeOptions.new
    #   )
    #   transport.connect
    #   transport.receive_messages do |message|
    #     puts message
    #   end
    #   transport.disconnect
    class SubprocessCLI < Transport
      # Maximum buffer size for JSON messages (1MB)
      MAX_BUFFER_SIZE = 1024 * 1024

      # @return [Logger] the logger instance
      attr_reader :logger

      # Initialize subprocess transport
      #
      # @param prompt [String] the prompt to send to Claude
      # @param options [ClaudeCodeOptions] configuration options
      # @param cli_path [String, Pathname, nil] path to Claude CLI binary
      def initialize(prompt:, options:, cli_path: nil) # rubocop:disable Lint/MissingSuper
        @prompt = prompt
        @options = options
        @cli_path = cli_path ? cli_path.to_s : find_cli
        @cwd = options.cwd&.to_s
        @pid = nil
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
        @logger = Logger.new($stderr)
        @logger.level = ENV["CLAUDE_SDK_DEBUG"] ? Logger::DEBUG : Logger::INFO
      end

      # Connect to Claude Code CLI
      #
      # @return [void]
      # @raise [CLIConnectionError] if unable to start the CLI
      def connect
        return if @pid

        cmd = build_command
        logger.debug("Executing command: #{cmd.join(" ")}")

        begin
          env = ENV.to_h.merge("CLAUDE_CODE_ENTRYPOINT" => "sdk-ruby")

          # Build spawn options
          spawn_options = {}
          spawn_options[:chdir] = @cwd if @cwd

          # Use Open3 to spawn process with pipes
          @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(env, *cmd, **spawn_options)
          @pid = @wait_thread.pid

          # Close stdin since we don't need it
          @stdin.close
        rescue Errno::ENOENT
          # Check if error is from working directory or CLI
          raise CLIConnectionError, "Working directory does not exist: #{@cwd}" if @cwd && !File.directory?(@cwd)

          raise CLINotFoundError.new(
            message: "Claude Code not found",
            cli_path: @cli_path,
          )
        rescue StandardError => e
          raise CLIConnectionError, "Failed to start Claude Code: #{e.message}"
        end
      end

      # Disconnect from Claude Code CLI
      #
      # @return [void]
      def disconnect
        return unless @pid

        begin
          # Try to terminate gracefully
          Process.kill("INT", @pid)

          # Wait for process to exit with timeout using the wait thread
          if @wait_thread&.alive?
            begin
              Timeout.timeout(5) do
                @wait_thread.join
              end
            rescue Timeout::Error
              # Force kill if it doesn't exit gracefully
              begin
                Process.kill("KILL", @pid)
              rescue StandardError
                nil
              end
              begin
                @wait_thread.join
              rescue StandardError
                nil
              end
            end
          end
        rescue Errno::ESRCH, Errno::ECHILD
          # Process already gone
        ensure
          @stdin&.close
          @stdout&.close
          @stderr&.close
          @stdin = nil
          @stdout = nil
          @stderr = nil
          @pid = nil
          @wait_thread = nil
        end
      end

      # Send request (not used for CLI transport - args passed via command line)
      #
      # @param messages [Array<Hash>] messages (ignored)
      # @param options [Hash] options (ignored)
      # @return [void]
      def send_request(messages, options)
        # Not used - all arguments passed via command line
      end

      # Receive messages from CLI output
      #
      # @yield [Hash] parsed JSON message from CLI
      # @return [Enumerator<Hash>] if no block given
      # @raise [ProcessError] if CLI exits with non-zero status
      # @raise [CLIJSONDecodeError] if unable to parse JSON
      def receive_messages
        return enum_for(:receive_messages) unless block_given?

        raise CLIConnectionError, "Not connected" unless @pid

        json_buffer = ""
        stderr_lines = []

        # Read stdout directly (not in async task to avoid conflicts)
        logger.debug("Starting to read stdout...")
        if @stdout
          begin
            @stdout.each_line do |line|
              logger.debug("Read line: #{line.inspect}")
              line_str = line.strip
              next if line_str.empty?

              # Split by newlines in case multiple JSON objects are on one line
              json_lines = line_str.split("\n")

              json_lines.each do |json_line|
                json_line.strip!
                next if json_line.empty?

                # Keep accumulating partial JSON until we can parse it
                json_buffer += json_line

                if json_buffer.length > MAX_BUFFER_SIZE
                  json_buffer = ""
                  raise CLIJSONDecodeError.new(
                    line: "Buffer exceeded #{MAX_BUFFER_SIZE} bytes",
                    original_error: StandardError.new("Buffer overflow"),
                  )
                end

                begin
                  data = JSON.parse(json_buffer)
                  json_buffer = ""
                  logger.debug("Parsed JSON: #{data["type"]}")
                  yield data
                rescue JSON::ParserError
                  # Keep accumulating
                end
              end
            end
          rescue IOError, Errno::EBADF
            # Stream was closed, that's ok
          end
        end

        # Collect stderr
        if @stderr
          begin
            @stderr.each_line do |line|
              stderr_lines << line.strip
            end
          rescue IOError, Errno::EBADF
            # Stream was closed, that's ok
          end
        end

        # Wait for process completion
        exit_status = nil
        if @wait_thread
          logger.debug("Waiting for process to complete...")
          @wait_thread.join
          exit_status = @wait_thread.value.exitstatus
          logger.debug("Process completed with status: #{exit_status}")
        end

        stderr_output = stderr_lines.join("\n")

        # Check exit status
        if exit_status && exit_status != 0
          raise ProcessError.new(
            "Command failed with exit code #{exit_status}",
            exit_code: exit_status,
            stderr: stderr_output,
          )
        elsif !stderr_output.empty?
          logger.debug("Process stderr: #{stderr_output}")
        end
      end

      # Check if subprocess is running
      #
      # @return [Boolean] true if connected and running
      def connected?
        return false unless @pid

        # Check if process is still running
        Process.kill(0, @pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end

      private

      # Find Claude Code CLI binary
      #
      # @return [String] path to CLI binary
      # @raise [CLINotFoundError] if CLI not found
      def find_cli
        # Check PATH first
        if (cli_path = which("claude"))
          return cli_path
        end

        # Check common locations
        locations = [
          Pathname.new(File.expand_path("~/.npm-global/bin/claude")),
          Pathname.new("/usr/local/bin/claude"),
          Pathname.new(File.expand_path("~/.local/bin/claude")),
          Pathname.new(File.expand_path("~/node_modules/.bin/claude")),
          Pathname.new(File.expand_path("~/.yarn/bin/claude")),
        ]

        locations.each do |path|
          return path.to_s if path.exist? && path.file?
        end

        # Check if Node.js is installed
        node_installed = !which("node").nil?

        unless node_installed
          error_msg = "Claude Code requires Node.js, which is not installed.\n\n"
          error_msg += "Install Node.js from: https://nodejs.org/\n"
          error_msg += "\nAfter installing Node.js, install Claude Code:\n"
          error_msg += "  npm install -g @anthropic-ai/claude-code"
          raise CLINotFoundError.new(message: error_msg, cli_path: @cli_path)
        end

        # Node is installed but Claude Code isn't
        error_msg = <<~MSG
          Claude Code not found. Install with:
            npm install -g @anthropic-ai/claude-code

          If already installed locally, try:
            export PATH="$HOME/node_modules/.bin:$PATH"

          Or specify the path when creating transport:
            SubprocessCLI.new(..., cli_path: '/path/to/claude')
        MSG
        raise CLINotFoundError.new(message: error_msg, cli_path: @cli_path)
      end

      # Cross-platform which command
      #
      # @param cmd [String] command to find
      # @return [String, nil] path to command or nil
      def which(cmd)
        exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
        ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
          exts.each do |ext|
            exe = File.join(path, "#{cmd}#{ext}")
            return exe if File.executable?(exe) && !File.directory?(exe)
          end
        end
        nil
      end

      # Build CLI command with arguments
      #
      # @return [Array<String>] command array
      def build_command
        cmd = [@cli_path, "--output-format", "stream-json", "--verbose"]

        cmd.push("--system-prompt", @options.system_prompt) if @options.system_prompt

        cmd.push("--append-system-prompt", @options.append_system_prompt) if @options.append_system_prompt

        if @options.allowed_tools && !@options.allowed_tools.empty?
          cmd.push("--allowedTools", @options.allowed_tools.join(","))
        end

        cmd.push("--max-turns", @options.max_turns.to_s) if @options.max_turns

        if @options.disallowed_tools && !@options.disallowed_tools.empty?
          cmd.push("--disallowedTools", @options.disallowed_tools.join(","))
        end

        cmd.push("--model", @options.model) if @options.model

        if @options.permission_prompt_tool_name
          cmd.push("--permission-prompt-tool", @options.permission_prompt_tool_name)
        end

        cmd.push("--permission-mode", format_permission_mode(@options.permission_mode)) if @options.permission_mode

        cmd.push("--continue") if @options.continue_conversation

        cmd.push("--resume", @options.resume) if @options.resume

        if @options.mcp_servers && !@options.mcp_servers.empty?
          mcp_config = { "mcpServers" => serialize_mcp_servers }
          cmd.push("--mcp-config", JSON.generate(mcp_config))
        end

        cmd.push("--print", @prompt)
        cmd
      end

      # Serialize MCP servers for CLI
      #
      # @return [Hash] serialized MCP servers
      def serialize_mcp_servers
        @options.mcp_servers.transform_values do |server|
          server.respond_to?(:to_h) ? server.to_h : server
        end
      end

      # Convert permission mode from Ruby symbol format to CLI camelCase format
      #
      # @param mode [Symbol] the permission mode symbol
      # @return [String] the camelCase formatted mode
      def format_permission_mode(mode)
        case mode
        when :default
          "default"
        when :accept_edits
          "acceptEdits"
        when :bypass_permissions
          "bypassPermissions"
        else
          mode.to_s
        end
      end
    end
  end
end
