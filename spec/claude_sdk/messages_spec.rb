# frozen_string_literal: true

require "spec_helper"

RSpec.describe(ClaudeSDK::Messages) do
  describe "Message types" do
    describe ClaudeSDK::Messages::User do
      it "creates a user message" do
        msg = described_class.new(content: "Hello, Claude!")
        expect(msg.content).to(eq("Hello, Claude!"))
        expect(msg.to_h).to(eq({ role: "user", content: "Hello, Claude!" }))
      end
    end

    describe ClaudeSDK::Messages::Assistant do
      it "creates an assistant message with text content" do
        text_block = ClaudeSDK::ContentBlock::Text.new(text: "Hello, human!")
        msg = described_class.new(content: [text_block])

        expect(msg.content.length).to(eq(1))
        expect(msg.content[0].text).to(eq("Hello, human!"))
        expect(msg.to_h).to(eq({
          role: "assistant",
          content: [{ type: "text", text: "Hello, human!" }],
        }))
      end
    end

    describe ClaudeSDK::Messages::Result do
      it "creates a result message" do
        msg = described_class.new(
          subtype: "success",
          duration_ms: 1500,
          duration_api_ms: 1200,
          is_error: false,
          num_turns: 1,
          session_id: "session-123",
          total_cost_usd: 0.01,
        )

        expect(msg.subtype).to(eq("success"))
        expect(msg.total_cost_usd).to(eq(0.01))
        expect(msg.session_id).to(eq("session-123"))

        hash = msg.to_h
        expect(hash[:role]).to(eq("result"))
        expect(hash[:subtype]).to(eq("success"))
        expect(hash[:total_cost_usd]).to(eq(0.01))
      end

      it "omits nil values from serialization" do
        msg = described_class.new(
          subtype: "success",
          duration_ms: 1000,
          duration_api_ms: 800,
          is_error: false,
          num_turns: 1,
          session_id: "test",
        )

        hash = msg.to_h
        expect(hash).not_to(have_key(:total_cost_usd))
        expect(hash).not_to(have_key(:usage))
        expect(hash).not_to(have_key(:result))
      end
    end
  end

  describe "Content block types" do
    describe ClaudeSDK::ContentBlock::ToolUse do
      it "creates a tool use block" do
        block = described_class.new(
          id: "tool-123",
          name: "Read",
          input: { file_path: "/test.txt" },
        )

        expect(block.id).to(eq("tool-123"))
        expect(block.name).to(eq("Read"))
        expect(block.input[:file_path]).to(eq("/test.txt"))

        expect(block.to_h).to(eq({
          type: "tool_use",
          id: "tool-123",
          name: "Read",
          input: { file_path: "/test.txt" },
        }))
      end
    end

    describe ClaudeSDK::ContentBlock::ToolResult do
      it "creates a tool result block" do
        block = described_class.new(
          tool_use_id: "tool-123",
          content: "File contents here",
          is_error: false,
        )

        expect(block.tool_use_id).to(eq("tool-123"))
        expect(block.content).to(eq("File contents here"))
        expect(block.is_error).to(be(false))

        expect(block.to_h).to(eq({
          type: "tool_result",
          tool_use_id: "tool-123",
          content: "File contents here",
          is_error: false,
        }))
      end

      it "omits nil values from serialization" do
        block = described_class.new(
          tool_use_id: "tool-123",
        )

        hash = block.to_h
        expect(hash).to(eq({
          type: "tool_result",
          tool_use_id: "tool-123",
        }))
        expect(hash).not_to(have_key(:content))
        expect(hash).not_to(have_key(:is_error))
      end
    end
  end

  describe ClaudeSDK::ClaudeCodeOptions do
    describe "default options" do
      it "has sensible defaults" do
        options = described_class.new

        expect(options.allowed_tools).to(eq([]))
        expect(options.max_thinking_tokens).to(eq(8000))
        expect(options.system_prompt).to(be_nil)
        expect(options.permission_mode).to(be_nil)
        expect(options.continue_conversation).to(be(false))
        expect(options.disallowed_tools).to(eq([]))
      end
    end

    describe "with tools" do
      it "accepts allowed and disallowed tools" do
        options = described_class.new(
          allowed_tools: ["Read", "Write", "Edit"],
          disallowed_tools: ["Bash"],
        )

        expect(options.allowed_tools).to(eq(["Read", "Write", "Edit"]))
        expect(options.disallowed_tools).to(eq(["Bash"]))
      end
    end

    describe "with permission mode" do
      it "accepts valid permission modes" do
        options = described_class.new(
          permission_mode: :bypass_permissions,
        )

        expect(options.permission_mode).to(eq(:bypass_permissions))
      end

      it "raises error for invalid permission mode" do
        expect do
          described_class.new(permission_mode: :invalid_mode)
        end.to(raise_error(ArgumentError, /Invalid permission mode/))
      end
    end

    describe "with system prompt" do
      it "accepts system prompt and append_system_prompt" do
        options = described_class.new(
          system_prompt: "You are a helpful assistant.",
          append_system_prompt: "Be concise.",
        )

        expect(options.system_prompt).to(eq("You are a helpful assistant."))
        expect(options.append_system_prompt).to(eq("Be concise."))
      end
    end

    describe "with session continuation" do
      it "accepts continue_conversation and resume" do
        options = described_class.new(
          continue_conversation: true,
          resume: "session-123",
        )

        expect(options.continue_conversation).to(be(true))
        expect(options.resume).to(eq("session-123"))
      end
    end

    describe "with model specification" do
      it "accepts model and permission_prompt_tool_name" do
        options = described_class.new(
          model: "claude-3-5-sonnet-20241022",
          permission_prompt_tool_name: "CustomTool",
        )

        expect(options.model).to(eq("claude-3-5-sonnet-20241022"))
        expect(options.permission_prompt_tool_name).to(eq("CustomTool"))
      end
    end

    describe "serialization" do
      it "serializes to hash with only non-default values" do
        options = described_class.new(
          allowed_tools: ["Read"],
          system_prompt: "Test prompt",
        )

        hash = options.to_h
        expect(hash[:allowed_tools]).to(eq(["Read"]))
        expect(hash[:system_prompt]).to(eq("Test prompt"))
        expect(hash).not_to(have_key(:max_thinking_tokens))
        expect(hash).not_to(have_key(:continue_conversation))
        expect(hash).not_to(have_key(:disallowed_tools))
      end

      it "converts permission mode to string" do
        options = described_class.new(
          permission_mode: :accept_edits,
        )

        hash = options.to_h
        expect(hash[:permission_mode]).to(eq("accept_edits"))
      end

      it "converts cwd pathname to string" do
        options = described_class.new(
          cwd: Pathname.new("/custom/path"),
        )

        hash = options.to_h
        expect(hash[:cwd]).to(eq("/custom/path"))
      end
    end
  end

  describe "PermissionMode" do
    it "defines valid permission modes" do
      expect(ClaudeSDK::PermissionMode::DEFAULT).to(eq(:default))
      expect(ClaudeSDK::PermissionMode::ACCEPT_EDITS).to(eq(:accept_edits))
      expect(ClaudeSDK::PermissionMode::BYPASS_PERMISSIONS).to(eq(:bypass_permissions))
    end

    it "validates permission modes" do
      expect(ClaudeSDK::PermissionMode.valid?(:default)).to(be(true))
      expect(ClaudeSDK::PermissionMode.valid?(:accept_edits)).to(be(true))
      expect(ClaudeSDK::PermissionMode.valid?(:bypass_permissions)).to(be(true))
      expect(ClaudeSDK::PermissionMode.valid?(:invalid)).to(be(false))
    end
  end
end
