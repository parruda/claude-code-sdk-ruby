# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe(ClaudeSDK::Error) do
  describe ClaudeSDK::Error do
    it "is the base error class" do
      error = described_class.new("Something went wrong")
      expect(error.message).to(eq("Something went wrong"))
      expect(error).to(be_a(StandardError))
    end
  end

  describe ClaudeSDK::CLINotFoundError do
    it "inherits from CLIConnectionError" do
      error = described_class.new(message: "Claude Code not found")
      expect(error).to(be_a(ClaudeSDK::CLIConnectionError))
      expect(error.message).to(include("Claude Code not found"))
    end

    it "includes cli_path in message when provided" do
      error = described_class.new(
        message: "Claude Code not found",
        cli_path: "/usr/local/bin/claude",
      )
      expect(error.message).to(eq("Claude Code not found: /usr/local/bin/claude"))
      expect(error.cli_path).to(eq("/usr/local/bin/claude"))
    end

    it "works without cli_path" do
      error = described_class.new
      expect(error.message).to(eq("Claude Code not found"))
      expect(error.cli_path).to(be_nil)
    end
  end

  describe ClaudeSDK::CLIConnectionError do
    it "inherits from Error" do
      error = described_class.new("Failed to connect to CLI")
      expect(error).to(be_a(ClaudeSDK::Error))
      expect(error.message).to(include("Failed to connect to CLI"))
    end
  end

  describe ClaudeSDK::ProcessError do
    it "includes exit code and stderr in message" do
      error = described_class.new(
        "Process failed",
        exit_code: 1,
        stderr: "Command not found",
      )

      expect(error.exit_code).to(eq(1))
      expect(error.stderr).to(eq("Command not found"))
      expect(error.message).to(include("Process failed"))
      expect(error.message).to(include("exit code: 1"))
      expect(error.message).to(include("Command not found"))
    end

    it "works with only message" do
      error = described_class.new("Process failed")
      expect(error.message).to(eq("Process failed"))
      expect(error.exit_code).to(be_nil)
      expect(error.stderr).to(be_nil)
    end

    it "works with only exit code" do
      error = described_class.new("Process failed", exit_code: 127)
      expect(error.message).to(eq("Process failed (exit code: 127)"))
      expect(error.exit_code).to(eq(127))
      expect(error.stderr).to(be_nil)
    end
  end

  describe ClaudeSDK::CLIJSONDecodeError do
    it "captures line and original error" do
      original_error = JSON::ParserError.new("unexpected token")
      error = described_class.new(
        line: "{invalid json}",
        original_error: original_error,
      )

      expect(error.line).to(eq("{invalid json}"))
      expect(error.original_error).to(eq(original_error))
      expect(error.message).to(include("Failed to decode JSON"))
    end

    it "truncates long lines in message" do
      long_line = "x" * 200
      error = described_class.new(
        line: long_line,
        original_error: StandardError.new,
      )

      expect(error.message).to(include("#{"x" * 100}..."))
      expect(error.line).to(eq(long_line)) # Full line is still accessible
    end
  end
end
