# frozen_string_literal: true

# Helper methods for async testing
module AsyncHelpers
  # Run an async block and wait for it to complete
  def run_async(&block)
    Async(&block).wait
  end

  # Create a mock async task
  def mock_async_task
    task = instance_double(Async::Task)
    allow(task).to(receive(:async).and_yield)
    task
  end
end

RSpec.configure do |config|
  config.include(AsyncHelpers)
end
