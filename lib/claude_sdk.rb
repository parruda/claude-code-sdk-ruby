# frozen_string_literal: true

require "async"

require_relative "claude_sdk/version"
require_relative "claude_sdk/errors"
require_relative "claude_sdk/types"
require_relative "claude_sdk/internal/client"

module ClaudeSDK
  class << self
    # Query Claude Code
    #
    # @param prompt [String] The prompt to send to Claude
    # @param options [ClaudeCodeOptions, nil] Optional configuration
    # @yield [Message] Messages from the conversation
    # @return [Enumerator] if no block given
    #
    # @example Simple usage
    #   ClaudeSDK.query("Hello") do |message|
    #     puts message
    #   end
    #
    # @example With options
    #   options = ClaudeSDK::ClaudeCodeOptions.new(
    #     system_prompt: "You are helpful",
    #     cwd: "/home/user"
    #   )
    #   ClaudeSDK.query("Hello", options: options) do |message|
    #     puts message
    #   end
    #
    # @example Without block (returns Enumerator)
    #   messages = ClaudeSDK.query("Hello")
    #   messages.each { |msg| puts msg }
    def query(prompt, options: nil, &block)
      options ||= ClaudeCodeOptions.new

      ENV["CLAUDE_CODE_ENTRYPOINT"] = "sdk-rb"

      client = Internal::InternalClient.new

      if block_given?
        Async do
          client.process_query(prompt: prompt, options: options, &block)
        end.wait
      else
        Enumerator.new do |yielder|
          Async do
            client.process_query(prompt: prompt, options: options) do |message|
              yielder << message
            end
          end
        end

      end
    end
  end
end
