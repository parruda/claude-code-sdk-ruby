# frozen_string_literal: true

# rubocop:disable Lint/UnusedBlockArgument

require "spec_helper"

RSpec.describe(ClaudeSDK) do
  describe "query with single prompt" do
    it "returns messages from a simple query" do
      # Mock the internal client
      client = instance_double(ClaudeSDK::Internal::InternalClient)
      allow(ClaudeSDK::Internal::InternalClient).to(receive(:new).and_return(client))

      # Mock the process_query method to yield a message
      allow(client).to(receive(:process_query)) do |prompt:, options:, &block|
        expect(prompt).to(eq("What is 2+2?"))
        expect(options).to(be_a(ClaudeSDK::ClaudeCodeOptions))

        # Simulate yielding an assistant message
        message = assistant_message(content: [text_block("4")])
        block.call(message)
      end

      # Run the query and collect messages
      messages = []
      described_class.query("What is 2+2?") do |msg|
        messages << msg
      end

      expect(messages.length).to(eq(1))
      expect(messages[0]).to(be_a(ClaudeSDK::Messages::Assistant))
      expect(messages[0].content[0].text).to(eq("4"))
    end
  end

  describe "query with options" do
    it "passes options correctly to the internal client" do
      client = instance_double(ClaudeSDK::Internal::InternalClient)
      allow(ClaudeSDK::Internal::InternalClient).to(receive(:new).and_return(client))

      options = claude_options(
        allowed_tools: ["Read", "Write"],
        system_prompt: "You are helpful",
        permission_mode: :accept_edits,
        max_turns: 5,
      )

      allow(client).to(receive(:process_query)) do |prompt:, options:, &block|
        expect(prompt).to(eq("Hi"))
        expect(options.allowed_tools).to(eq(["Read", "Write"]))
        expect(options.system_prompt).to(eq("You are helpful"))
        expect(options.permission_mode).to(eq(:accept_edits))
        expect(options.max_turns).to(eq(5))

        message = assistant_message(content: [text_block("Hello!")])
        block.call(message)
      end

      messages = []
      described_class.query("Hi", options: options) do |msg|
        messages << msg
      end

      expect(messages.length).to(eq(1))
    end
  end

  describe "query with custom working directory" do
    it "creates transport with correct cwd option" do
      transport = instance_double(ClaudeSDK::Internal::SubprocessCLI)
      allow(ClaudeSDK::Internal::SubprocessCLI).to(receive(:new).and_return(transport))

      allow(transport).to(receive(:connect))
      allow(transport).to(receive(:disconnect))
      allow(transport).to(receive(:receive_messages).and_yield({
        "type" => "assistant",
        "message" => {
          "role" => "assistant",
          "content" => [{ "type" => "text", "text" => "Done" }],
        },
      }).and_yield({
        "type" => "result",
        "subtype" => "success",
        "duration_ms" => 1000,
        "duration_api_ms" => 800,
        "is_error" => false,
        "num_turns" => 1,
        "session_id" => "test-session",
        "total_cost_usd" => 0.001,
      }))

      options = claude_options(cwd: "/custom/path")
      messages = []

      described_class.query("test", options: options) do |msg|
        messages << msg
      end

      # Verify transport was created with correct parameters
      expect(ClaudeSDK::Internal::SubprocessCLI).to(have_received(:new).with(
        prompt: "test",
        options: having_attributes(cwd: "/custom/path"),
      ))

      expect(messages.length).to(eq(2))
      expect(messages[0]).to(be_a(ClaudeSDK::Messages::Assistant))
      expect(messages[1]).to(be_a(ClaudeSDK::Messages::Result))
    end
  end

  describe "query with settings file" do
    it "passes settings option correctly to the internal client" do
      client = instance_double(ClaudeSDK::Internal::InternalClient)
      allow(ClaudeSDK::Internal::InternalClient).to(receive(:new).and_return(client))

      options = claude_options(
        settings: "/path/to/settings.json",
      )

      allow(client).to(receive(:process_query)) do |prompt:, options:, &block|
        expect(prompt).to(eq("Test"))
        expect(options.settings).to(eq("/path/to/settings.json"))

        message = assistant_message(content: [text_block("Settings loaded")])
        block.call(message)
      end

      messages = []
      described_class.query("Test", options: options) do |msg|
        messages << msg
      end

      expect(messages.length).to(eq(1))
    end
  end

  describe "query without block" do
    it "returns an Enumerator when no block is given" do
      client = instance_double(ClaudeSDK::Internal::InternalClient)
      allow(ClaudeSDK::Internal::InternalClient).to(receive(:new).and_return(client))

      allow(client).to(receive(:process_query)) do |prompt:, options:, &block|
        message = assistant_message(content: [text_block("Hello from enumerator")])
        block.call(message)
      end

      result = described_class.query("test")
      expect(result).to(be_a(Enumerator))

      messages = result.to_a
      expect(messages.length).to(eq(1))
      expect(messages[0].content[0].text).to(eq("Hello from enumerator"))
    end
  end

  describe "environment variable" do
    it "sets CLAUDE_CODE_ENTRYPOINT to sdk-rb" do
      client = instance_double(ClaudeSDK::Internal::InternalClient)
      allow(ClaudeSDK::Internal::InternalClient).to(receive(:new).and_return(client))
      allow(client).to(receive(:process_query))

      described_class.query("test") { |_| nil }

      expect(ENV.fetch("CLAUDE_CODE_ENTRYPOINT", nil)).to(eq("sdk-rb"))
    end
  end
end

# rubocop:enable Lint/UnusedBlockArgument
