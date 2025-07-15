#!/usr/bin/env ruby
# frozen_string_literal: true

require "claude_sdk"

# Example showing how to use bypass permissions mode
# This will pass --permission-mode bypassPermissions to the CLI

options = ClaudeSDK::ClaudeCodeOptions.new(
  permission_mode: :bypass_permissions,
)

client = ClaudeSDK::Client.new(options)

begin
  response = client.query("List the files in the current directory")

  response.each do |message|
    if message["type"] == "user"
      puts "User: #{message["content"]}"
    elsif message["type"] == "assistant"
      message["content"].each do |block|
        if block["type"] == "text"
          puts "Assistant: #{block["text"]}"
        end
      end
    end
  end
rescue ClaudeSDK::CLINotFoundError => e
  puts "Error: #{e.message}"
  puts "Please install Claude Code CLI first"
rescue StandardError => e
  puts "Error: #{e.message}"
end
