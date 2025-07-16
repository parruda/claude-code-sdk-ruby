# frozen_string_literal: true

require "pathname"

module ClaudeSDK
  # Permission modes for Claude Code
  module PermissionMode
    # Default permission mode
    DEFAULT = :default

    # Accept edits automatically
    ACCEPT_EDITS = :accept_edits

    # Bypass permission checks
    BYPASS_PERMISSIONS = :bypass_permissions

    # Valid permission modes
    ALL = [DEFAULT, ACCEPT_EDITS, BYPASS_PERMISSIONS].freeze

    # Validate if a mode is valid
    #
    # @param mode [Symbol] the mode to validate
    # @return [Boolean] true if valid
    class << self
      def valid?(mode)
        ALL.include?(mode)
      end
    end
  end

  # MCP Server configurations
  module McpServerConfig
    # MCP stdio server configuration
    #
    # @!attribute command [String] the command to execute
    # @!attribute args [Array<String>] command arguments
    # @!attribute env [Hash<String, String>] environment variables
    # @!attribute type [Symbol] always :stdio
    class StdioServer
      attr_accessor :command, :args, :env
      attr_reader :type

      # @param command [String] the command to execute
      # @param args [Array<String>] command arguments
      # @param env [Hash<String, String>] environment variables
      def initialize(command:, args: [], env: {})
        @type = :stdio
        @command = command
        @args = args
        @env = env
      end

      # Convert to hash for JSON serialization
      #
      # @return [Hash]
      def to_h
        hash = { command: command }
        hash[:type] = type.to_s unless type == :stdio # Optional for backwards compatibility
        hash[:args] = args unless args.empty?
        hash[:env] = env unless env.empty?
        hash
      end
    end

    # MCP SSE server configuration
    #
    # @!attribute url [String] the server URL
    # @!attribute headers [Hash<String, String>] HTTP headers
    # @!attribute type [Symbol] always :sse
    class SSEServer
      attr_accessor :url, :headers
      attr_reader :type

      # @param url [String] the server URL
      # @param headers [Hash<String, String>] HTTP headers
      def initialize(url:, headers: {})
        @type = :sse
        @url = url
        @headers = headers
      end

      # Convert to hash for JSON serialization
      #
      # @return [Hash]
      def to_h
        hash = { type: type.to_s, url: url }
        hash[:headers] = headers unless headers.empty?
        hash
      end
    end

    # MCP HTTP server configuration
    #
    # @!attribute url [String] the server URL
    # @!attribute headers [Hash<String, String>] HTTP headers
    # @!attribute type [Symbol] always :http
    class HttpServer
      attr_accessor :url, :headers
      attr_reader :type

      # @param url [String] the server URL
      # @param headers [Hash<String, String>] HTTP headers
      def initialize(url:, headers: {})
        @type = :http
        @url = url
        @headers = headers
      end

      # Convert to hash for JSON serialization
      #
      # @return [Hash]
      def to_h
        hash = { type: type.to_s, url: url }
        hash[:headers] = headers unless headers.empty?
        hash
      end
    end
  end

  # Content block types
  module ContentBlock
    # Text content block
    #
    # @!attribute text [String] the text content
    class Text
      attr_accessor :text

      # @param text [String] the text content
      def initialize(text:)
        @text = text
      end

      # @return [Hash] serialized representation
      def to_h
        { type: "text", text: text }
      end
    end

    # Tool use content block
    #
    # @!attribute id [String] unique identifier for this tool use
    # @!attribute name [String] the tool name
    # @!attribute input [Hash<String, Object>] tool input parameters
    class ToolUse
      attr_accessor :id, :name, :input

      # @param id [String] unique identifier
      # @param name [String] tool name
      # @param input [Hash<String, Object>] tool input
      def initialize(id:, name:, input:)
        @id = id
        @name = name
        @input = input
      end

      # @return [Hash] serialized representation
      def to_h
        { type: "tool_use", id: id, name: name, input: input }
      end
    end

    # Tool result content block
    #
    # @!attribute tool_use_id [String] ID of the corresponding tool use
    # @!attribute content [String, Array<Hash>, nil] the result content
    # @!attribute is_error [Boolean, nil] whether this is an error result
    class ToolResult
      attr_accessor :tool_use_id, :content, :is_error

      # @param tool_use_id [String] ID of the tool use
      # @param content [String, Array<Hash>, nil] result content
      # @param is_error [Boolean, nil] error flag
      def initialize(tool_use_id:, content: nil, is_error: nil)
        @tool_use_id = tool_use_id
        @content = content
        @is_error = is_error
      end

      # @return [Hash] serialized representation
      def to_h
        hash = { type: "tool_result", tool_use_id: tool_use_id }
        hash[:content] = content unless content.nil?
        hash[:is_error] = is_error unless is_error.nil?
        hash
      end
    end
  end

  # Message types
  module Messages
    # User message
    #
    # @!attribute content [String] the message content
    class User
      attr_accessor :content

      # @param content [String] the message content
      def initialize(content:)
        @content = content
      end

      # @return [Hash] serialized representation
      def to_h
        { role: "user", content: content }
      end
    end

    # Assistant message with content blocks
    #
    # @!attribute content [Array<ContentBlock::Text, ContentBlock::ToolUse, ContentBlock::ToolResult>] content blocks
    class Assistant
      attr_accessor :content

      # @param content [Array<ContentBlock>] content blocks
      def initialize(content:)
        @content = content
      end

      # @return [Hash] serialized representation
      def to_h
        { role: "assistant", content: content.map(&:to_h) }
      end
    end

    # System message with metadata
    #
    # @!attribute subtype [String] the system message subtype
    # @!attribute data [Hash<String, Object>] metadata
    class System
      attr_accessor :subtype, :data

      # @param subtype [String] message subtype
      # @param data [Hash<String, Object>] metadata
      def initialize(subtype:, data:)
        @subtype = subtype
        @data = data
      end

      # @return [Hash] serialized representation
      def to_h
        { role: "system", subtype: subtype, data: data }
      end
    end

    # Result message with cost and usage information
    #
    # @!attribute subtype [String] the result subtype
    # @!attribute duration_ms [Integer] total duration in milliseconds
    # @!attribute duration_api_ms [Integer] API duration in milliseconds
    # @!attribute is_error [Boolean] whether this is an error result
    # @!attribute num_turns [Integer] number of conversation turns
    # @!attribute session_id [String] unique session identifier
    # @!attribute total_cost_usd [Float, nil] total cost in USD
    # @!attribute usage [Hash<String, Object>, nil] usage statistics
    # @!attribute result [String, nil] the result content
    class Result
      attr_accessor :subtype,
        :duration_ms,
        :duration_api_ms,
        :is_error,
        :num_turns,
        :session_id,
        :total_cost_usd,
        :usage,
        :result

      # @param subtype [String] result subtype
      # @param duration_ms [Integer] total duration
      # @param duration_api_ms [Integer] API duration
      # @param is_error [Boolean] error flag
      # @param num_turns [Integer] turn count
      # @param session_id [String] session ID
      # @param total_cost_usd [Float, nil] cost in USD
      # @param usage [Hash, nil] usage stats
      # @param result [String, nil] result content
      def initialize(subtype:, duration_ms:, duration_api_ms:, is_error:,
        num_turns:, session_id:, total_cost_usd: nil,
        usage: nil, result: nil)
        @subtype = subtype
        @duration_ms = duration_ms
        @duration_api_ms = duration_api_ms
        @is_error = is_error
        @num_turns = num_turns
        @session_id = session_id
        @total_cost_usd = total_cost_usd
        @usage = usage
        @result = result
      end

      # @return [Hash] serialized representation
      def to_h
        hash = {
          role: "result",
          subtype: subtype,
          duration_ms: duration_ms,
          duration_api_ms: duration_api_ms,
          is_error: is_error,
          num_turns: num_turns,
          session_id: session_id,
        }
        hash[:total_cost_usd] = total_cost_usd unless total_cost_usd.nil?
        hash[:usage] = usage unless usage.nil?
        hash[:result] = result unless result.nil?
        hash
      end
    end
  end

  # Query options for Claude SDK
  #
  # @!attribute allowed_tools [Array<String>] list of allowed tools
  # @!attribute max_thinking_tokens [Integer] maximum thinking tokens
  # @!attribute system_prompt [String, nil] system prompt override
  # @!attribute append_system_prompt [String, nil] additional system prompt
  # @!attribute mcp_tools [Array<String>] MCP tools to enable
  # @!attribute mcp_servers [Hash<String, McpServerConfig>] MCP server configurations
  # @!attribute permission_mode [Symbol, nil] permission mode
  # @!attribute continue_conversation [Boolean] continue existing conversation
  # @!attribute resume [String, nil] resume from session ID
  # @!attribute max_turns [Integer, nil] maximum conversation turns
  # @!attribute disallowed_tools [Array<String>] list of disallowed tools
  # @!attribute model [String, nil] model to use
  # @!attribute permission_prompt_tool_name [String, nil] permission prompt tool
  # @!attribute cwd [String, Pathname, nil] working directory
  class ClaudeCodeOptions
    attr_accessor :allowed_tools,
      :max_thinking_tokens,
      :system_prompt,
      :append_system_prompt,
      :mcp_tools,
      :mcp_servers,
      :permission_mode,
      :continue_conversation,
      :resume,
      :max_turns,
      :disallowed_tools,
      :model,
      :permission_prompt_tool_name,
      :cwd,
      :session_id

    # Initialize with default values
    #
    # @param allowed_tools [Array<String>] allowed tools (default: [])
    # @param max_thinking_tokens [Integer] max thinking tokens (default: 8000)
    # @param system_prompt [String, nil] system prompt
    # @param append_system_prompt [String, nil] append to system prompt
    # @param mcp_tools [Array<String>] MCP tools (default: [])
    # @param mcp_servers [Hash] MCP servers (default: {})
    # @param permission_mode [Symbol, nil] permission mode
    # @param continue_conversation [Boolean] continue conversation (default: false)
    # @param resume [String, nil] resume session ID
    # @param max_turns [Integer, nil] max turns
    # @param disallowed_tools [Array<String>] disallowed tools (default: [])
    # @param model [String, nil] model name
    # @param permission_prompt_tool_name [String, nil] permission tool
    # @param cwd [String, Pathname, nil] working directory
    # @param session_id [String, nil] session ID (must be a valid UUID)
    def initialize(allowed_tools: [],
      max_thinking_tokens: 8000,
      system_prompt: nil,
      append_system_prompt: nil,
      mcp_tools: [],
      mcp_servers: {},
      permission_mode: nil,
      continue_conversation: false,
      resume: nil,
      max_turns: nil,
      disallowed_tools: [],
      model: nil,
      permission_prompt_tool_name: nil,
      cwd: nil,
      session_id: nil)
      @allowed_tools = allowed_tools
      @max_thinking_tokens = max_thinking_tokens
      @system_prompt = system_prompt
      @append_system_prompt = append_system_prompt
      @mcp_tools = mcp_tools
      @mcp_servers = mcp_servers
      @permission_mode = permission_mode
      @continue_conversation = continue_conversation
      @resume = resume
      @max_turns = max_turns
      @disallowed_tools = disallowed_tools
      @model = model
      @permission_prompt_tool_name = permission_prompt_tool_name
      @cwd = cwd
      @session_id = session_id

      validate_permission_mode! if permission_mode
    end

    # Convert to hash for JSON serialization
    #
    # @return [Hash]
    def to_h
      hash = {}
      hash[:allowed_tools] = allowed_tools unless allowed_tools.empty?
      hash[:max_thinking_tokens] = max_thinking_tokens if max_thinking_tokens != 8000
      hash[:system_prompt] = system_prompt if system_prompt
      hash[:append_system_prompt] = append_system_prompt if append_system_prompt
      hash[:mcp_tools] = mcp_tools unless mcp_tools.empty?
      hash[:mcp_servers] = serialize_mcp_servers unless mcp_servers.empty?
      hash[:permission_mode] = permission_mode.to_s if permission_mode
      hash[:continue_conversation] = continue_conversation if continue_conversation
      hash[:resume] = resume if resume
      hash[:max_turns] = max_turns if max_turns
      hash[:disallowed_tools] = disallowed_tools unless disallowed_tools.empty?
      hash[:model] = model if model
      hash[:permission_prompt_tool_name] = permission_prompt_tool_name if permission_prompt_tool_name
      hash[:cwd] = cwd.to_s if cwd
      hash[:session_id] = session_id if session_id
      hash
    end

    private

    # Validate permission mode
    def validate_permission_mode!
      return if PermissionMode.valid?(@permission_mode)

      raise ArgumentError, "Invalid permission mode: #{@permission_mode}"
    end

    # Serialize MCP servers to hashes
    def serialize_mcp_servers
      mcp_servers.transform_values do |server|
        server.respond_to?(:to_h) ? server.to_h : server
      end
    end
  end
end
