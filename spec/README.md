# Claude SDK Ruby Test Suite

This directory contains the RSpec test suite for the Claude SDK Ruby implementation, converted from the original Python pytest tests.

## Test Structure

```
spec/
├── spec_helper.rb                    # Main RSpec configuration
├── claude_sdk/
│   ├── client_spec.rb               # Tests for main query functionality
│   ├── errors_spec.rb               # Tests for error classes
│   ├── types_spec.rb                # Tests for type definitions
│   └── internal/
│       └── transport/
│           ├── subprocess_cli_spec.rb        # Transport layer tests
│           └── subprocess_buffering_spec.rb  # JSON buffering edge cases
└── integration/
    └── claude_sdk_spec.rb           # End-to-end integration tests
```

## Running Tests

### Prerequisites

1. Ruby 3.0+ installed
2. Bundler installed (`gem install bundler`)

### Install Dependencies

```bash
cd ruby_gem
bundle install
```

### Run All Tests

```bash
bundle exec rspec
```

### Run Specific Test File

```bash
bundle exec rspec spec/claude_sdk/client_spec.rb
```

### Run with Coverage Report

The test suite automatically generates coverage reports using SimpleCov:

```bash
bundle exec rspec
open coverage/index.html  # View coverage report
```

### Run with Detailed Output

```bash
bundle exec rspec --format documentation
```

## Test Coverage

The test suite covers:

- **Client Tests**: Main query interface and message handling
- **Error Tests**: All error classes and their behavior
- **Type Tests**: Message types, content blocks, and options
- **Transport Tests**: CLI subprocess management and command building
- **Buffering Tests**: Complex JSON parsing scenarios and edge cases
- **Integration Tests**: End-to-end functionality with mocked CLI responses

## Async Testing

The test suite uses `Async::RSpec` for testing asynchronous operations. Async blocks are used to properly test the async behavior of the SDK.

## Test Helpers

The `spec_helper.rb` provides useful helper methods:

- `text_block(text)` - Create a text content block
- `tool_use_block(id:, name:, input:)` - Create a tool use block
- `tool_result_block(tool_use_id:, content:, is_error:)` - Create a tool result block
- `assistant_message(content:)` - Create an assistant message
- `user_message(content:)` - Create a user message
- `result_message(...)` - Create a result message
- `claude_options(...)` - Create ClaudeCodeOptions

## Mocking

The tests use RSpec's built-in mocking framework with:
- `instance_double` for creating test doubles
- `allow` and `expect` for setting up method stubs and expectations
- Mock subprocess and async streams for testing transport behavior

## Debugging Tests

To debug a specific test:

```ruby
it 'my test' do
  binding.pry  # Add debugger breakpoint
  # test code
end
```

Make sure to add `pry` to your Gemfile development dependencies.