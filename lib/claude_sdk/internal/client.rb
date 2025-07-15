# frozen_string_literal: true

require "async"
require_relative "transport/subprocess_cli"

module ClaudeSDK
  module Internal
    # Internal client implementation for processing queries through transport
    #
    # This client handles the communication with Claude Code CLI via the
    # transport layer and parses the received messages into Ruby objects.
    #
    # @example
    #   client = InternalClient.new
    #   Async do
    #     client.process_query("Hello Claude", options) do |message|
    #       puts message
    #     end
    #   end
    class InternalClient
      # Initialize the internal client
      def initialize
        # Currently no initialization needed
      end

      # Process a query through transport
      #
      # @param prompt [String] the prompt to send to Claude
      # @param options [ClaudeCodeOptions] configuration options
      # @yield [Messages::User, Messages::Assistant, Messages::System, Messages::Result] parsed message
      # @return [Enumerator] if no block given
      def process_query(prompt:, options:)
        return enum_for(:process_query, prompt: prompt, options: options) unless block_given?

        transport = SubprocessCLI.new(
          prompt: prompt,
          options: options,
        )

        begin
          transport.connect

          transport.receive_messages do |data|
            message = parse_message(data)
            yield message if message
          end
        ensure
          transport.disconnect
        end
      end

      private

      # Parse message from CLI output
      #
      # @param data [Hash] raw message data from CLI
      # @return [Messages::User, Messages::Assistant, Messages::System, Messages::Result, nil] parsed message
      def parse_message(data)
        case data["type"]
        when "user"
          Messages::User.new(
            content: data.dig("message", "content"),
          )

        when "assistant"
          content_blocks = parse_content_blocks(data.dig("message", "content") || [])
          Messages::Assistant.new(content: content_blocks)

        when "system"
          Messages::System.new(
            subtype: data["subtype"],
            data: data,
          )

        when "result"
          Messages::Result.new(
            subtype: data["subtype"],
            duration_ms: data["duration_ms"],
            duration_api_ms: data["duration_api_ms"],
            is_error: data["is_error"],
            num_turns: data["num_turns"],
            session_id: data["session_id"],
            total_cost_usd: data["total_cost_usd"],
            usage: data["usage"],
            result: data["result"],
          )

        end
      end

      # Parse content blocks from assistant message
      #
      # @param blocks [Array<Hash>] raw content blocks
      # @return [Array<ContentBlock::Text, ContentBlock::ToolUse, ContentBlock::ToolResult>] parsed blocks
      def parse_content_blocks(blocks)
        blocks.map do |block|
          case block["type"]
          when "text"
            ContentBlock::Text.new(
              text: block["text"],
            )

          when "tool_use"
            ContentBlock::ToolUse.new(
              id: block["id"],
              name: block["name"],
              input: block["input"],
            )

          when "tool_result"
            ContentBlock::ToolResult.new(
              tool_use_id: block["tool_use_id"],
              content: block["content"],
              is_error: block["is_error"],
            )

          end
        end.compact
      end
    end
  end
end
