#!/usr/bin/env ruby
# frozen_string_literal: true

require "claude_sdk"

# Example: Proper error handling with ClaudeSDK

begin
  ClaudeSDK.query("Hello, Claude!") do |message|
    puts message.inspect
  end
rescue ClaudeSDK::CLINotFoundError => e
  puts "❌ Claude CLI not found!"
  puts e.message
  puts "\nTo install Claude CLI:"
  puts "  npm install -g @anthropic-ai/claude-code"
rescue ClaudeSDK::CLIConnectionError => e
  puts "❌ Failed to connect to Claude CLI"
  puts e.message
rescue ClaudeSDK::ProcessError => e
  puts "❌ Process failed"
  puts "Exit code: #{e.exit_code}"
  puts "Error output: #{e.stderr}"
rescue ClaudeSDK::Error => e
  # Catch any other ClaudeSDK errors
  puts "❌ An error occurred: #{e.message}"
rescue StandardError => e
  # Catch unexpected errors
  puts "❌ Unexpected error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n")
end
