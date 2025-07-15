#!/usr/bin/env ruby
# frozen_string_literal: true

require "claude_sdk"

# Example: Using enumerators for fine-grained control

# Get an enumerator instead of using a block
messages = ClaudeSDK.query("Write a haiku about Ruby programming")

# Process messages with more control
message_count = 0
assistant_messages = []

begin
  loop do
    message = messages.next
    message_count += 1

    case message
    when ClaudeSDK::Messages::User
      puts "📨 Message #{message_count}: User prompt received"

    when ClaudeSDK::Messages::Assistant
      assistant_messages << message
      text_blocks = message.content.select { |b| b.is_a?(ClaudeSDK::ContentBlock::Text) }
      puts "🤖 Message #{message_count}: Assistant responded with #{text_blocks.count} text blocks"

      # We could break early if we wanted
      # break if text_blocks.any? { |b| b.text.include?("haiku") }

    when ClaudeSDK::Messages::System
      puts "⚙️  Message #{message_count}: System message (#{message.subtype})"

    when ClaudeSDK::Messages::Result
      puts "✅ Message #{message_count}: Completed in #{message.duration_ms}ms"
      break # End of conversation
    end
  end
rescue StopIteration
  # Normal end of enumeration
end

# Display the haiku
puts "\n📝 Generated Haiku:"
assistant_messages.each do |msg|
  msg.content.each do |block|
    puts block.text if block.is_a?(ClaudeSDK::ContentBlock::Text)
  end
end
