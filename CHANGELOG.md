# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-07-15

### Added
- Initial release of claude-code-sdk-ruby
- Core SDK functionality for interacting with Claude Code CLI
- Support for async query processing
- Message types: User, Assistant, System, and Result
- Content blocks: Text, ToolUse, and ToolResult
- Configuration options via ClaudeCodeOptions
- Error handling with specific error types:
  - CLINotFoundError
  - CLIConnectionError  
  - ProcessError
- Internal client for direct subprocess communication
- Comprehensive test suite with RSpec
- Examples and documentation

### Dependencies
- async (~> 2.0)

### Development Dependencies
- bundler (~> 2.0)
- rake (~> 13.0)
- rspec (~> 3.0)
- rubocop (~> 1.50)
- rubocop-rspec (~> 2.20)
- simplecov (~> 0.22)
- yard (~> 0.9)

[Unreleased]: https://github.com/parruda/claude-code-sdk-ruby/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/parruda/claude-code-sdk-ruby/releases/tag/v0.1.0