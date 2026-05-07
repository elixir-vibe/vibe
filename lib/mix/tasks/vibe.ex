defmodule Mix.Tasks.Vibe do
  @shortdoc "Launch Vibe, the minimal BEAM-native coding agent"

  @moduledoc """
  Launches Vibe.

  ## Usage

  Installed command:

      vibe                        # Start server if needed and attach the TUI
      vibe [options] [message...]
      vibe --web [--port 4321]
      vibe server start [--foreground]
      vibe server restart
      vibe server status
      vibe server stop
      vibe new                    # Create and attach a fresh session. Alias: vibe n
      vibe sessions [--all] [--live] [--failed] [--limit n]  # Alias: vibe ls
      vibe sessions prune --empty
      vibe send <session-id> "prompt"
      vibe storage migrate
      vibe storage status
      vibe storage fts status
      vibe storage fts rebuild
      vibe storage fts optimize
      vibe storage checkpoint
      vibe storage vacuum
      vibe search <query> [--cwd project] [--role user|assistant|tool] [--include-tools]
      vibe storage search <query> [--cwd project] [--role user|assistant|tool] [--include-tools]
      vibe storage import pi <path> [--no-fts] [--rebuild-fts] [--batch-size N]
      vibe skill list|show <name>|apis|from-session <session-id> <name>
      vibe attach                 # Alias: vibe a
      vibe attach <session-id>    # Alias: vibe a <session-id>

  From a checkout:

      mix vibe
      mix vibe [options] [message...]

  ## Options

    * `--model <provider:model>` - ReqLLM/Jido model.
      Defaults to `VIBE_MODEL` or `openai_codex:gpt-5.5`.
    * `--api-key <key>` - API key for OpenAI-compatible requests.
    * `--system-prompt <text>` - Override system prompt for direct TUI/`--direct` calls.
    * `--mode <text|json>` - Output mode. Defaults to `text`.
    * `--print`, `-p` - Non-interactive mode: process prompt and exit.
    * `--direct` - Use direct ReqLLM call instead of the tool-capable Jido.AI agent.
    * `--stream` - Stream direct ReqLLM calls. Default for `--direct`.
    * `--no-stream` - Disable direct ReqLLM streaming.
    * `--eval <code>` - Evaluate Elixir code through `Vibe.Eval`.
    * `--compact` - Compact stored trajectory context.
    * `--web` - Start the prototype Phoenix LiveView web interface.
    * `--port <port>` - Port for `--web`. Defaults to 4321.
    * `--keep-recent <n>` - Events to keep when compacting. Defaults to `12`.
    * `--checks` - Run Vibe validation gates.
    * `--codex-usage` - Show Codex subscription usage via Codex app-server RPC.
    * `--session <id>` - Continue or name a persisted session.
    * `--sessions` - List persisted sessions. Prefer `vibe sessions` for server-aware listings.
    * `--all` - With `vibe sessions`, include empty/internal historical sessions.
    * `--live` - With `vibe sessions`, show only live sessions.
    * `--failed` - With `vibe sessions`, show sessions whose preview looks failed.
    * `--limit <n>` - With `vibe sessions`, limit displayed sessions. Defaults to `20`.
    * `--timeout <ms>` - Request/eval timeout.
    * `--cast <path>` - Record the TUI byte stream as a native gzip cast for debugging.
    * `--login codex` - Sign in with ChatGPT/Codex OAuth.
    * `--help`, `-h` - Show this help.
    * `--version`, `-v` - Show version.

  ## Examples

      vibe
      vibe -p "Inspect runtime info with eval"
      vibe --model anthropic:claude-sonnet-4-5-20250929 "Review this project"
      vibe --login codex
      vibe --compact --keep-recent 20
      vibe --eval "Vibe.OTP.runtime_info()"
      vibe new --mode json
      vibe ls --limit 5
      vibe send 20260425-120000-abcd "Use eval to inspect System.version()"
      vibe storage search "figma variable"
      vibe a
      vibe a 20260425-120000-abcd
  """

  use Mix.Task

  @impl true
  def run(argv) do
    Mix.Task.run("app.start")
    Vibe.CLI.main(argv)
  end
end
