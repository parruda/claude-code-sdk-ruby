# frozen_string_literal: true

module ClaudeSDK
  # Base exception for all Claude SDK errors
  #
  # @abstract All Claude SDK errors inherit from this class
  class Error < StandardError; end

  # Raised when unable to connect to Claude Code
  #
  # @see CLINotFoundError
  class CLIConnectionError < Error; end

  # Raised when Claude Code is not found or not installed
  #
  # @example
  #   raise CLINotFoundError.new("Claude Code not found", cli_path: "/usr/local/bin/claude")
  class CLINotFoundError < CLIConnectionError
    # @return [String, nil] the path where Claude Code was expected
    attr_reader :cli_path

    # @param message [String] the error message
    # @param cli_path [String, nil] the path where Claude Code was expected
    def initialize(message: "Claude Code not found", cli_path: nil)
      @cli_path = cli_path
      message = "#{message}: #{cli_path}" if cli_path
      super(message)
    end
  end

  # Raised when the CLI process fails
  #
  # @example
  #   raise ProcessError.new("Command failed", exit_code: 1, stderr: "Error output")
  class ProcessError < Error
    # @return [Integer, nil] the process exit code
    attr_reader :exit_code

    # @return [String, nil] the stderr output from the process
    attr_reader :stderr

    # @param message [String] the error message
    # @param exit_code [Integer, nil] the process exit code
    # @param stderr [String, nil] the stderr output
    def initialize(message, exit_code: nil, stderr: nil)
      @exit_code = exit_code
      @stderr = stderr

      message = "#{message} (exit code: #{exit_code})" if exit_code
      message = "#{message}\nError output: #{stderr}" if stderr

      super(message)
    end
  end

  # Raised when unable to decode JSON from CLI output
  #
  # @example
  #   raise CLIJSONDecodeError.new("invalid json", original_error: JSON::ParserError.new)
  class CLIJSONDecodeError < Error
    # @return [String] the line that failed to decode
    attr_reader :line

    # @return [Exception] the original JSON parsing error
    attr_reader :original_error

    # @param line [String] the line that failed to decode
    # @param original_error [Exception] the original JSON parsing error
    def initialize(line:, original_error:)
      @line = line
      @original_error = original_error
      super("Failed to decode JSON: #{line[0..99]}...")
    end
  end
end
