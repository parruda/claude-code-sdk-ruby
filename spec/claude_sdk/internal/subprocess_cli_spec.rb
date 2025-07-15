# frozen_string_literal: true

require "spec_helper"
require "pathname"

RSpec.describe(ClaudeSDK::Internal::SubprocessCLI) do
  let(:prompt) { "test prompt" }
  let(:options) { ClaudeSDK::ClaudeCodeOptions.new }
  let(:cli_path) { "/usr/bin/claude" }

  describe "#find_cli" do
    context "when CLI is not found" do
      it "raises CLINotFoundError" do
        allow_any_instance_of(described_class).to(receive(:which).and_return(nil)) # rubocop:disable RSpec/AnyInstance
        allow(Pathname).to(receive(:new).and_call_original)
        allow_any_instance_of(Pathname).to(receive(:exist?).and_return(false)) # rubocop:disable RSpec/AnyInstance

        expect { described_class.new(prompt: prompt, options: options) }
          .to(raise_error(ClaudeSDK::CLINotFoundError)) do |error|
            expect(error.message).to(include("Claude Code requires Node.js"))
          end
      end
    end
  end

  describe "#build_command" do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path,
      )
    end

    it "builds basic CLI command" do
      cmd = transport.send(:build_command)

      expect(cmd[0]).to(eq(cli_path))
      expect(cmd).to(include("--output-format", "stream-json"))
      expect(cmd).to(include("--verbose"))
      expect(cmd).to(include("--print", prompt))
    end

    it "accepts pathlib.Path objects for cli_path" do
      transport = described_class.new(
        prompt: "Hello",
        options: options,
        cli_path: Pathname.new("/usr/bin/claude"),
      )

      expect(transport.instance_variable_get(:@cli_path)).to(eq("/usr/bin/claude"))
    end

    it "includes options in command" do
      options = ClaudeSDK::ClaudeCodeOptions.new(
        system_prompt: "Be helpful",
        allowed_tools: ["Read", "Write"],
        disallowed_tools: ["Bash"],
        model: "claude-3-5-sonnet",
        permission_mode: :accept_edits,
        max_turns: 5,
      )

      transport = described_class.new(
        prompt: "test",
        options: options,
        cli_path: cli_path,
      )

      cmd = transport.send(:build_command)

      expect(cmd).to(include("--system-prompt", "Be helpful"))
      expect(cmd).to(include("--allowedTools", "Read,Write"))
      expect(cmd).to(include("--disallowedTools", "Bash"))
      expect(cmd).to(include("--model", "claude-3-5-sonnet"))
      expect(cmd).to(include("--permission-mode", "accept_edits"))
      expect(cmd).to(include("--max-turns", "5"))
    end

    it "includes session continuation options" do
      options = ClaudeSDK::ClaudeCodeOptions.new(
        continue_conversation: true,
        resume: "session-123",
      )

      transport = described_class.new(
        prompt: "Continue from before",
        options: options,
        cli_path: cli_path,
      )

      cmd = transport.send(:build_command)

      expect(cmd).to(include("--continue"))
      expect(cmd).to(include("--resume", "session-123"))
    end
  end

  describe "#connect and #disconnect" do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path,
      )
    end

    it "manages process lifecycle" do
      stdout_r, stdout_w = IO.pipe
      stderr_r, stderr_w = IO.pipe

      allow(IO).to(receive(:pipe).and_return([stdout_r, stdout_w], [stderr_r, stderr_w]))
      # Test uses Open3.popen3, not Async::Process
      allow(Process).to(receive(:kill).with(0, 12_345).and_return(1))
      allow(Process).to(receive(:kill).with("INT", 12_345))
      allow(Process).to(receive(:wait).with(12_345))

      Async do
        transport.connect
        expect(transport.connected?).to(be(true))

        transport.disconnect
        expect(Process).to(have_received(:kill).with("INT", 12_345))
      end
    end
  end

  describe "#receive_messages" do
    subject(:transport) do
      described_class.new(
        prompt: prompt,
        options: options,
        cli_path: cli_path,
      )
    end

    # This test is simplified since the actual async stream handling
    # is tested in integration tests
    it "requires connection" do
      expect do
        transport.receive_messages { |_| nil }
      end.to(raise_error(ClaudeSDK::CLIConnectionError, "Not connected"))
    end
  end

  describe "#connect with nonexistent cwd" do
    it "raises CLIConnectionError when cwd does not exist" do
      options = ClaudeSDK::ClaudeCodeOptions.new(
        cwd: "/this/directory/does/not/exist",
      )

      transport = described_class.new(
        prompt: "test",
        options: options,
        cli_path: cli_path,
      )

      allow(Open3).to(receive(:popen3).and_raise(
        Errno::ENOENT, "No such file or directory"
      ))

      Async do
        expect { transport.connect }
          .to(raise_error(ClaudeSDK::CLIConnectionError)) do |error|
            expect(error.message).to(include("/this/directory/does/not/exist"))
          end
      end
    end
  end
end
