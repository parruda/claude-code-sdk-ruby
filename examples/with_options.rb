#!/usr/bin/env ruby
# frozen_string_literal: true

require "claude_sdk"

# Example: Using ClaudeSDK with various options

# Create options with custom settings
options = ClaudeSDK::ClaudeCodeOptions.new(
  system_prompt: "You are a helpful Ruby programming assistant",
  cwd: Dir.pwd,
  max_thinking_tokens: 10_000,
  permission_mode: :accept_edits, # Auto-accept file edits
  allowed_tools: ["bash", "read", "write"],
  model: "claude-3.5-sonnet",
)

# Query with options
ClaudeSDK.query("Write a Ruby function to calculate fibonacci numbers", options: options) do |message|
  case message
  when ClaudeSDK::Messages::User
    puts "\n👤 User: #{message.content}"
  when ClaudeSDK::Messages::Assistant
    message.content.each do |block|
      case block
      when ClaudeSDK::ContentBlock::Text
        puts "\n🤖 Claude: #{block.text}"
      when ClaudeSDK::ContentBlock::ToolUse
        puts "\n🔧 Using tool: #{block.name}"
        puts "   Input: #{block.input.inspect}"
      when ClaudeSDK::ContentBlock::ToolResult
        puts "\n📊 Tool result: #{block.content}"
      end
    end
  when ClaudeSDK::Messages::Result
    puts "\n✅ Completed!"
    puts "   Duration: #{message.duration_ms}ms"
    puts "   API calls: #{message.duration_api_ms}ms"
    puts "   Total cost: $#{format("%.4f", message.total_cost_usd || 0)}"
  end
end
