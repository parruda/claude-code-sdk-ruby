#!/usr/bin/env ruby
# frozen_string_literal: true

# Add lib to load path for development
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "async"
require "claude_sdk/types"
require "claude_sdk/errors"
require "claude_sdk/internal/client"

# Example of using the Ruby Claude SDK internal client
#
# This demonstrates:
# - Creating an internal client
# - Processing a query with options
# - Handling different message types
# - Error handling

# Create options
options = ClaudeSDK::ClaudeCodeOptions.new(
  allowed_tools: ["bash", "read"],
  max_turns: 3,
  system_prompt: "You are a helpful coding assistant.",
)

# Create client
client = ClaudeSDK::Internal::InternalClient.new

# Process query
Async do
  puts "Sending query to Claude..."
  puts "=" * 50

  client.process_query("What is 2+2?", options) do |message|
    case message
    when ClaudeSDK::Messages::User
      puts "\n[USER]"
      puts message.content

    when ClaudeSDK::Messages::Assistant
      puts "\n[ASSISTANT]"
      message.content.each do |block|
        case block
        when ClaudeSDK::ContentBlock::Text
          puts block.text
        when ClaudeSDK::ContentBlock::ToolUse
          puts "Tool Use: #{block.name}"
          puts "Input: #{block.input.inspect}"
        when ClaudeSDK::ContentBlock::ToolResult
          puts "Tool Result for #{block.tool_use_id}"
          puts "Content: #{block.content}"
          puts "Error: #{block.is_error}" if block.is_error
        end
      end

    when ClaudeSDK::Messages::System
      puts "\n[SYSTEM: #{message.subtype}]"
      puts message.data.inspect

    when ClaudeSDK::Messages::Result
      puts "\n[RESULT]"
      puts "Session ID: #{message.session_id}"
      puts "Duration: #{message.duration_ms}ms (API: #{message.duration_api_ms}ms)"
      puts "Turns: #{message.num_turns}"
      puts "Cost: $#{message.total_cost_usd}" if message.total_cost_usd
      puts "Error: #{message.is_error}" if message.is_error
    end
  end
rescue ClaudeSDK::CLINotFoundError => e
  puts "Error: #{e.message}"
  puts "Please install Claude Code CLI first"
rescue ClaudeSDK::CLIConnectionError => e
  puts "Connection error: #{e.message}"
rescue ClaudeSDK::ProcessError => e
  puts "Process error: #{e.message}"
  puts "Exit code: #{e.exit_code}" if e.exit_code
  puts "Stderr: #{e.stderr}" if e.stderr
rescue StandardError => e
  puts "Unexpected error: #{e.class} - #{e.message}"
  puts e.backtrace
end
