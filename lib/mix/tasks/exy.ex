defmodule Mix.Tasks.Exy do
  @shortdoc "Launch Exy, the minimal BEAM-native coding agent"

  @moduledoc """
  Launches Exy.

  ## Usage

  Installed command:

      exy                        # Start server if needed and attach the TUI
      exy [options] [message...]
      exy --web [--port 4321]
      exy server start [--foreground]
      exy server status
      exy server stop
      exy new                    # Create and attach a fresh session. Alias: exy n
      exy sessions [--all] [--live] [--failed] [--limit n]  # Alias: exy ls
      exy sessions prune --empty
      exy send <session-id> "prompt"
      exy storage migrate
      exy storage status
      exy storage fts status
      exy storage fts rebuild
      exy storage fts optimize
      exy storage checkpoint
      exy storage vacuum
      exy search <query> [--cwd project] [--role user|assistant|tool] [--include-tools]
      exy storage search <query> [--cwd project] [--role user|assistant|tool] [--include-tools]
      exy storage import pi <path> [--no-fts] [--rebuild-fts] [--batch-size N]
      exy skill list|show <name>|apis|from-session <session-id> <name>
      exy attach                 # Alias: exy a
      exy attach <session-id>    # Alias: exy a <session-id>

  From a checkout:

      mix exy
      mix exy [options] [message...]

  ## Options

    * `--model <provider:model>` - ReqLLM/Jido model.
      Defaults to `EXY_MODEL` or `openai_codex:gpt-5.5`.
    * `--api-key <key>` - API key for OpenAI-compatible requests.
    * `--system-prompt <text>` - Override system prompt for direct TUI/`--direct` calls.
    * `--mode <text|json>` - Output mode. Defaults to `text`.
    * `--print`, `-p` - Non-interactive mode: process prompt and exit.
    * `--direct` - Use direct ReqLLM call instead of the tool-capable Jido.AI agent.
    * `--stream` - Stream direct ReqLLM calls. Default for `--direct`.
    * `--no-stream` - Disable direct ReqLLM streaming.
    * `--eval <code>` - Evaluate Elixir code through `Exy.Eval`.
    * `--compact` - Compact stored trajectory context.
    * `--web` - Start the prototype Phoenix LiveView web interface.
    * `--port <port>` - Port for `--web`. Defaults to 4321.
    * `--keep-recent <n>` - Events to keep when compacting. Defaults to `12`.
    * `--checks` - Run Exy validation gates.
    * `--codex-usage` - Show Codex subscription usage via Codex app-server RPC.
    * `--session <id>` - Continue or name a persisted session.
    * `--sessions` - List persisted sessions. Prefer `exy sessions` for server-aware listings.
    * `--all` - With `exy sessions`, include empty/internal historical sessions.
    * `--live` - With `exy sessions`, show only live sessions.
    * `--failed` - With `exy sessions`, show sessions whose preview looks failed.
    * `--limit <n>` - With `exy sessions`, limit displayed sessions. Defaults to `20`.
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
      exy new --mode json
      exy ls --limit 5
      exy send 20260425-120000-abcd "Use eval to inspect System.version()"
      exy storage search "figma variable"
      exy a
      exy a 20260425-120000-abcd
  """

  use Mix.Task

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")
    Exy.CLI.main(argv)
  end
end
