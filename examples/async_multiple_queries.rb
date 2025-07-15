#!/usr/bin/env ruby
# frozen_string_literal: true

require "claude_sdk"
require "async"

# Example: Running multiple queries concurrently

Async do |task|
  queries = [
    "What is the capital of France?",
    "Explain Ruby blocks in one sentence",
    "List 3 benefits of async programming",
  ]

  # Run queries concurrently
  results = queries.map do |prompt|
    task.async do
      responses = []
      ClaudeSDK.query(prompt) do |message|
        if message.is_a?(ClaudeSDK::Messages::Assistant)
          message.content.each do |block|
            responses << block.text if block.is_a?(ClaudeSDK::ContentBlock::Text)
          end
        end
      end
      { prompt: prompt, response: responses.join(" ") }
    end
  end.map(&:wait)

  # Display results
  results.each do |result|
    puts "\n💭 Question: #{result[:prompt]}"
    puts "💡 Answer: #{result[:response]}"
  end
end
