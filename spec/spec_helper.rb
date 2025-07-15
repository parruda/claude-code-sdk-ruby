# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"
end

require "bundler/setup"
require "claude_sdk"
require "async"
require "async/rspec"

# Include support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end

  # Include Async::RSpec for async testing
  config.include(Async::RSpec)

  # Run specs in random order to surface order dependencies
  config.order = :random

  # Seed global randomization
  Kernel.srand(config.seed)

  # Allow focused tests in development
  config.filter_run_when_matching(:focus)

  # Verify mocks
  config.mock_with(:rspec) do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end

  # Shared context for async tests
  config.shared_context_metadata_behavior = :apply_to_host_groups
end

# Helper method to create a mock subprocess
def mock_subprocess(stdout_lines: [], stderr_lines: [], exit_status: 0)
  process = instance_double(Process::Waiter)

  stdout = instance_double(IO)
  stderr = instance_double(IO)

  allow(stdout).to(receive(:each_line)) do |&block|
    stdout_lines.each(&block)
  end

  allow(stderr).to(receive(:each_line)) do |&block|
    stderr_lines.each(&block)
  end

  allow(process).to(receive_messages(stdout: stdout, stderr: stderr, wait: exit_status, running?: false))
  allow(process).to(receive(:terminate))

  process
end

# Helper for creating mock async streams
class MockAsyncStream
  include Enumerable

  def initialize(lines)
    @lines = lines
  end

  def each(&block)
    return enum_for(:each) unless block_given?

    @lines.each(&block)
  end

  def each_line(&block)
    return enum_for(:each_line) unless block_given?

    @lines.each(&block)
  end
end

# Test helpers for message creation
module TestHelpers
  def text_block(text)
    ClaudeSDK::ContentBlock::Text.new(text: text)
  end

  def tool_use_block(id:, name:, input:)
    ClaudeSDK::ContentBlock::ToolUse.new(id: id, name: name, input: input)
  end

  def tool_result_block(tool_use_id:, content:, is_error: false)
    ClaudeSDK::ContentBlock::ToolResult.new(
      tool_use_id: tool_use_id,
      content: content,
      is_error: is_error,
    )
  end

  def assistant_message(content:)
    ClaudeSDK::Messages::Assistant.new(content: content)
  end

  def user_message(content:)
    ClaudeSDK::Messages::User.new(content: content)
  end

  def result_message(
    subtype:,
    duration_ms:,
    duration_api_ms:,
    is_error: false,
    num_turns: 1,
    session_id: "test-session",
    total_cost_usd: 0.001,
    usage: nil,
    result: nil
  )
    ClaudeSDK::Messages::Result.new(
      subtype: subtype,
      duration_ms: duration_ms,
      duration_api_ms: duration_api_ms,
      is_error: is_error,
      num_turns: num_turns,
      session_id: session_id,
      total_cost_usd: total_cost_usd,
      usage: usage,
      result: result,
    )
  end

  def claude_options(**kwargs)
    ClaudeSDK::ClaudeCodeOptions.new(**kwargs)
  end
end

RSpec.configure do |config|
  config.include(TestHelpers)
end
