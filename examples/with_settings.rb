#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "claude_sdk"
require "json"
require "tmpdir"

# Example demonstrating how to use the --settings flag
# This creates a temporary settings file and uses it with the SDK

Dir.mktmpdir do |tmpdir|
  # Create a sample settings file
  settings_path = File.join(tmpdir, "claude-settings.json")

  settings_content = {
    "permissions" => {
      "allow" => [
        "Bash(npm run lint)",
        "Bash(npm run test:*)",
        "Read(~/.zshrc)",
      ],
      "deny" => [
        "Bash(curl:*)",
      ],
    },
    "env" => {
      "CLAUDE_CODE_ENABLE_TELEMETRY" => "1",
      "OTEL_METRICS_EXPORTER" => "otlp",
    },
    "model" => "claude-3-5-sonnet-20241022",
    "cleanupPeriodDays" => 20,
    "includeCoAuthoredBy" => true,
  }

  File.write(settings_path, JSON.pretty_generate(settings_content))

  puts "Created settings file at: #{settings_path}"
  puts "Settings content:"
  puts JSON.pretty_generate(settings_content)
  puts "\n---\n\n"

  # Create options with the settings file path
  options = ClaudeSDK::ClaudeCodeOptions.new(
    settings: settings_path,
    model: "sonnet",
  )

  # Query Claude with the settings
  puts "Querying Claude with settings file..."

  ClaudeSDK.query("What is 2 + 2?", options: options) do |message|
    if message.is_a?(Hash)
      type = message["type"]

      case type
      when "text"
        print(message["text"])
      when "result"
        puts "\n\nResult: #{message["result"]}" if message["result"]
      end
    end
  end
end
