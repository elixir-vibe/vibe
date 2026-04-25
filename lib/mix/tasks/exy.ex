defmodule Mix.Tasks.Exy do
  @shortdoc "Launch Exy, the minimal BEAM-native coding agent"

  @moduledoc """
  Launches Exy.

  ## Usage

      exy                        # Start the interactive TUI when installed
      exy [options] [message...]
      mix exy                    # Run from a checkout
      mix exy [options] [message...]

  ## Options

    * `--model <provider:model>` - ReqLLM/Jido model.
      Defaults to `EXY_MODEL` or `openai_codex:gpt-5.5`.
    * `--api-key <key>` - API key for OpenAI-compatible requests.
    * `--system-prompt <text>` - Override system prompt for direct TUI/`--no-agent` calls.
    * `--mode <text|json>` - Output mode. Defaults to `text`.
    * `--print`, `-p` - Non-interactive mode: process prompt and exit.
    * `--no-agent` - Use direct ReqLLM call instead of Jido.AI agent.
    * `--stream` - Stream direct ReqLLM calls. Default for `--no-agent`.
    * `--no-stream` - Disable direct ReqLLM streaming.
    * `--eval <code>` - Evaluate Elixir code through `Exy.Eval`.
    * `--compact` - Compact stored trajectory context.
    * `--keep-recent <n>` - Events to keep when compacting. Defaults to `12`.
    * `--checks` - Run Exy validation gates.
    * `--codex-usage` - Show Codex subscription usage via Codex app-server RPC.
    * `--session <id>` - Continue or name a persisted JSONL session.
    * `--sessions` - List persisted sessions.
    * `--timeout <ms>` - Request/eval timeout.
    * `--login codex` - Sign in with ChatGPT/Codex OAuth.
    * `--help`, `-h` - Show this help.
    * `--version`, `-v` - Show version.

  ## Examples

      exy
      exy -p "Inspect runtime info with eval"
      exy --model anthropic:claude-sonnet-4-5-20250929 "Review this project"
      exy --login codex
      exy --compact --keep-recent 20
      exy --eval "Exy.OTP.runtime_info()"
  """

  use Mix.Task

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")
    Exy.CLI.main(argv)
  end
end
