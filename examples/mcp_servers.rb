#!/usr/bin/env ruby
# frozen_string_literal: true

require "claude_sdk"

# Example: Using MCP (Model Context Protocol) servers

# Configure MCP servers
mcp_servers = {
  "filesystem" => {
    type: "stdio",
    command: "npx",
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"],
  },
  "git" => {
    type: "stdio",
    command: "npx",
    args: ["-y", "@modelcontextprotocol/server-git", "--repository", "."],
  },
}

# Create options with MCP servers
options = ClaudeSDK::ClaudeCodeOptions.new(
  mcp_servers: mcp_servers,
  mcp_tools: ["read_file", "write_file", "git_status", "git_diff"],
)

# Query using MCP tools
ClaudeSDK.query("Read the README.md file and summarize it", options: options) do |message|
  case message
  when ClaudeSDK::Messages::Assistant
    message.content.each do |block|
      if block.is_a?(ClaudeSDK::ContentBlock::ToolUse) && block.name.start_with?("mcp_")
        puts "🔌 Using MCP tool: #{block.name}"
        puts "   Server: #{block.name.split("_")[1]}"
        puts "   Input: #{block.input.inspect}"
      elsif block.is_a?(ClaudeSDK::ContentBlock::Text)
        puts "📝 #{block.text}"
      end
    end
  when ClaudeSDK::Messages::Result
    puts "\n✅ Done! Used #{message.num_turns} turns"
  end
end
