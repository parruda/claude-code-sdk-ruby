# frozen_string_literal: true

require "spec_helper"

RSpec.describe(ClaudeSDK) do
  describe "end-to-end functionality with mocked CLI responses" do
    describe "simple query response" do
      it "processes a simple text response" do
        transport = instance_double(ClaudeSDK::Internal::SubprocessCLI)
        allow(ClaudeSDK::Internal::SubprocessCLI).to(receive(:new).and_return(transport))

        allow(transport).to(receive(:connect))
        allow(transport).to(receive(:disconnect))
        allow(transport).to(receive(:receive_messages).and_yield({
          "type" => "assistant",
          "message" => {
            "role" => "assistant",
            "content" => [{ "type" => "text", "text" => "2 + 2 equals 4" }],
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

        messages = []
        described_class.query("What is 2 + 2?") do |msg|
          messages << msg
        end

        # Verify results
        expect(messages.length).to(eq(2))

        # Check assistant message
        expect(messages[0]).to(be_a(ClaudeSDK::Messages::Assistant))
        expect(messages[0].content.length).to(eq(1))
        expect(messages[0].content[0].text).to(eq("2 + 2 equals 4"))

        # Check result message
        expect(messages[1]).to(be_a(ClaudeSDK::Messages::Result))
        expect(messages[1].total_cost_usd).to(eq(0.001))
        expect(messages[1].session_id).to(eq("test-session"))
      end
    end

    describe "query with tool use" do
      it "processes messages with tool usage" do
        transport = instance_double(ClaudeSDK::Internal::SubprocessCLI)
        allow(ClaudeSDK::Internal::SubprocessCLI).to(receive(:new).and_return(transport))

        allow(transport).to(receive(:connect))
        allow(transport).to(receive(:disconnect))
        allow(transport).to(receive(:receive_messages).and_yield({
          "type" => "assistant",
          "message" => {
            "role" => "assistant",
            "content" => [
              {
                "type" => "text",
                "text" => "Let me read that file for you.",
              },
              {
                "type" => "tool_use",
                "id" => "tool-123",
                "name" => "Read",
                "input" => { "file_path" => "/test.txt" },
              },
            ],
          },
        }).and_yield({
          "type" => "result",
          "subtype" => "success",
          "duration_ms" => 1500,
          "duration_api_ms" => 1200,
          "is_error" => false,
          "num_turns" => 1,
          "session_id" => "test-session-2",
          "total_cost_usd" => 0.002,
        }))

        options = ClaudeSDK::ClaudeCodeOptions.new(allowed_tools: ["Read"])
        messages = []

        described_class.query("Read /test.txt", options: options) do |msg|
          messages << msg
        end

        # Verify results
        expect(messages.length).to(eq(2))

        # Check assistant message with tool use
        assistant_msg = messages[0]
        expect(assistant_msg).to(be_a(ClaudeSDK::Messages::Assistant))
        expect(assistant_msg.content.length).to(eq(2))
        expect(assistant_msg.content[0].text).to(eq("Let me read that file for you."))

        tool_use = assistant_msg.content[1]
        expect(tool_use).to(be_a(ClaudeSDK::ContentBlock::ToolUse))
        expect(tool_use.name).to(eq("Read"))
        expect(tool_use.input["file_path"]).to(eq("/test.txt"))
      end
    end

    describe "CLI not found" do
      it "raises appropriate error when CLI is not available" do
        # Mock the SubprocessCLI to raise error on initialization
        allow(ClaudeSDK::Internal::SubprocessCLI).to(receive(:new).and_raise(
          ClaudeSDK::CLINotFoundError.new(
            message: "Claude Code requires Node.js, which is not installed",
            cli_path: nil,
          ),
        ))

        # The error happens inside Async block
        # When we pass a block, the error is raised immediately
        error_caught = false

        begin
          described_class.query("test") do |msg|
            # This block won't be reached due to the error
          end
        rescue ClaudeSDK::CLINotFoundError => e
          error_caught = true
          expect(e.message).to(include("Claude Code requires Node.js"))
        end

        expect(error_caught).to(be(true))
      end
    end

    describe "continuation option" do
      it "supports continuing conversations" do
        transport = instance_double(ClaudeSDK::Internal::SubprocessCLI)

        # Verify transport is created with continuation option
        allow(ClaudeSDK::Internal::SubprocessCLI).to(receive(:new)) do |args|
          expect(args[:options].continue_conversation).to(be(true))
          transport
        end

        allow(transport).to(receive(:connect))
        allow(transport).to(receive(:disconnect))
        allow(transport).to(receive(:receive_messages).and_yield({
          "type" => "assistant",
          "message" => {
            "role" => "assistant",
            "content" => [
              {
                "type" => "text",
                "text" => "Continuing from previous conversation",
              },
            ],
          },
        }))

        options = ClaudeSDK::ClaudeCodeOptions.new(continue_conversation: true)
        messages = []

        described_class.query("Continue", options: options) do |msg|
          messages << msg
        end

        expect(messages.length).to(eq(1))
        expect(messages[0].content[0].text).to(eq("Continuing from previous conversation"))

        # Verify the expectation was met
        expect(ClaudeSDK::Internal::SubprocessCLI).to(have_received(:new))
      end
    end
  end
end
