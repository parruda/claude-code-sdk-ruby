# Claude Code SDK Ruby

[![Gem Version](https://badge.fury.io/rb/claude-code-sdk-ruby.svg)](https://badge.fury.io/rb/claude-code-sdk-ruby)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Official Ruby SDK for interacting with Claude Code CLI. This gem provides a Ruby-idiomatic interface to Claude Code with full async support, proper error handling, and comprehensive type definitions.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'claude-code-sdk-ruby'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install claude-code-sdk-ruby
```

## Prerequisites

This SDK requires the Claude Code CLI to be installed:

```bash
npm install -g @anthropic-ai/claude-code
```

You'll also need to configure your API key. Please refer to the [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for detailed setup instructions.

## Quick Start

```ruby
require 'claude_sdk'

# Simple query
ClaudeSDK.query("What is 2+2?") do |message|
  case message
  when ClaudeSDK::Messages::Assistant
    message.content.each do |block|
      puts block.text if block.is_a?(ClaudeSDK::ContentBlock::Text)
    end
  when ClaudeSDK::Messages::Result
    puts "Session completed in #{message.duration_ms}ms"
  end
end
```

## Usage

### Basic Query

```ruby
require 'claude_sdk'

ClaudeSDK.query("Hello, Claude!") do |message|
  puts message
end
```

### With Options

```ruby
require 'claude_sdk'

options = ClaudeSDK::ClaudeCodeOptions.new(
  allowed_tools: ['Read', 'Write', 'Bash'],
  max_turns: 3,
  system_prompt: 'You are a helpful coding assistant.',
  cwd: '/path/to/working/directory'
)

ClaudeSDK.query("Help me write a Ruby script", options: options) do |message|
  case message
  when ClaudeSDK::Messages::Assistant
    message.content.each do |block|
      case block
      when ClaudeSDK::ContentBlock::Text
        puts block.text
      when ClaudeSDK::ContentBlock::ToolUse
        puts "Tool: #{block.name}"
        puts "Input: #{block.input}"
      end
    end
  when ClaudeSDK::Messages::Result
    puts "Completed in #{message.num_turns} turns"
    puts "Total cost: $#{message.total_cost_usd}"
  end
end
```

### Without Block (Returns Enumerator)

```ruby
require 'claude_sdk'

messages = ClaudeSDK.query("Hello")
messages.each do |message|
  puts message
end
```

### Using Settings Files

You can load additional settings from a JSON file:

```ruby
require 'claude_sdk'

# Create options with a settings file path
options = ClaudeSDK::ClaudeCodeOptions.new(
  settings: '/path/to/claude-settings.json',
  model: 'sonnet'  # Other options can still be specified
)

ClaudeSDK.query("Hello", options: options) do |message|
  puts message
end
```

The settings file should be a valid JSON file containing Claude Code configuration options:

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test:*)",
      "Read(~/.zshrc)"
    ],
    "deny": [
      "Bash(curl:*)"
    ]
  },
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_METRICS_EXPORTER": "otlp"
  },
  "model": "claude-3-5-sonnet-20241022",
  "cleanupPeriodDays": 20,
  "includeCoAuthoredBy": true
}
```

### Advanced: Using the Internal Client Directly

```ruby
require 'claude_sdk/internal/client'

client = ClaudeSDK::Internal::InternalClient.new
options = ClaudeSDK::ClaudeCodeOptions.new(
  allowed_tools: ['Read', 'Bash'],
  max_turns: 5
)

Async do
  client.process_query(prompt: "What files are in this directory?", options: options) do |message|
    case message
    when ClaudeSDK::Messages::Assistant
      puts "Assistant response received"
    when ClaudeSDK::Messages::System
      puts "System message: #{message.subtype}"
    when ClaudeSDK::Messages::Result
      puts "Query completed"
    end
  end
end
```

## Message Types

The SDK provides several message types:

- `ClaudeSDK::Messages::User` - User input messages
- `ClaudeSDK::Messages::Assistant` - Assistant responses containing content blocks
- `ClaudeSDK::Messages::System` - System messages (tool results, errors)
- `ClaudeSDK::Messages::Result` - Query completion results with timing and cost info
- `ClaudeSDK::Messages::Error` - Error messages from the CLI

## Content Blocks

Assistant messages contain content blocks:

- `ClaudeSDK::ContentBlock::Text` - Text content
- `ClaudeSDK::ContentBlock::ToolUse` - Tool usage
- `ClaudeSDK::ContentBlock::ToolResult` - Tool results

## Configuration Options

The `ClaudeCodeOptions` class supports all Claude Code CLI options:

- `allowed_tools` - Array of allowed tool names (e.g., `['Read', 'Write', 'Bash']`)
- `disallowed_tools` - Array of disallowed tool names
- `max_turns` - Maximum conversation turns
- `system_prompt` - System prompt for the conversation
- `append_system_prompt` - Additional system prompt to append
- `cwd` - Working directory for file operations
- `model` - Model to use (e.g., `'claude-3-opus'`)
- `permission_mode` - Permission mode (`:default`, `:accept_edits`, `:auto`, `:ask`)
- `permission_prompt_tool_name` - Tool for permission prompts
- `continue_conversation` - Whether to continue from previous conversation
- `resume` - Resume from a specific conversation ID
- `mcp_servers` - MCP server configuration
- `settings` - Path to a settings JSON file to load additional settings from

## Error Handling

The SDK provides specific error types:

```ruby
begin
  ClaudeSDK.query("Hello") do |message|
    puts message
  end
rescue ClaudeSDK::CLINotFoundError => e
  puts "Claude Code CLI not found: #{e.message}"
rescue ClaudeSDK::CLIConnectionError => e
  puts "Connection error: #{e.message}"
rescue ClaudeSDK::ProcessError => e
  puts "Process error: #{e.message}"
end
```

## Requirements

- Ruby 3.0 or higher
- Node.js (for Claude Code CLI)
- async gem for async support

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
# Run tests
bundle exec rspec

# Run tests with coverage
COVERAGE=true bundle exec rspec

# Build the gem
gem build claude-code-sdk-ruby.gemspec

# Install locally
gem install ./claude-code-sdk-ruby-0.1.0.gem
```

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/parruda/claude-code-sdk-ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).