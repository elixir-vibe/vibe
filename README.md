# Vibe

BEAM-native coding agent for Elixir/OTP projects.

Vibe is an experimental terminal/web coding agent that runs on the BEAM. It uses supervised Elixir processes for sessions, command jobs, subagents, plugin workers, UI state, telemetry, and local storage instead of treating agent work as only files plus shell commands.

> [!WARNING]
> Vibe is experimental and not production-ready. It can run commands, edit files, store local state, start background processes, and talk to external model providers. Use it at your own risk, review changes before applying them, and avoid pointing it at repositories or machines where unintended agent actions would be costly.

## Install

Install the released executable from Hex:

```bash
mix escript.install hex vibe
export PATH="$HOME/.mix/escripts:$PATH"
```

Sign in with ChatGPT/Codex OAuth if you use the Codex/OpenAI provider:

```bash
vibe --login codex
```

Requirements: Elixir 1.19+, Erlang/OTP 27+, and credentials for the model provider you select. Vibe stores local runtime state under `~/.vibe` by default.

## Quick start

Start the TUI. If no background server is running, Vibe starts one and attaches to a server-owned session:

```bash
vibe
```

Open the web console for the same background server:

```bash
vibe --web
# or type /web in the TUI
```

Run one non-interactive prompt:

```bash
vibe -p "Inspect this project and suggest next steps"
```

Useful first slash commands:

```text
/help        Show built-in docs
/model       Pick a model and reasoning effort
/sessions    Browse sessions
/new         Start another session
/goal TASK   Set a persistent goal for long-running work
/web         Open the web console
```

## What Vibe is for

Vibe is useful when you want an agent that can:

- inspect and call Elixir APIs from a running BEAM;
- keep durable local sessions, eval state, memory, telemetry, goals, jobs, and tool output in SQLite;
- attach multiple TUI/web clients to the same session;
- run commands and subagents as supervised work that can be monitored, cancelled, and resumed;
- use Elixir helper APIs through `eval` instead of exposing many narrow model-facing tools.

Good fit: Elixir/OTP projects, long debugging/refactoring sessions, runtime introspection, local memory/search, and agent workflows that benefit from OTP supervision.

Less ideal: quick one-off prompting, production automation, or environments where local SQLite-backed state and command execution are not acceptable.

## Core commands

| Command | Purpose |
| --- | --- |
| `vibe` | Start/attach the TUI |
| `vibe --web [--port 4321]` | Ensure the background server is running and open the web console |
| `vibe -p "prompt"` | Run a prompt and exit |
| `vibe new` / `vibe n` | Create and attach a fresh server session |
| `vibe sessions` / `vibe ls` | List recent sessions |
| `vibe send <session-id> "prompt"` | Send work to an existing session |
| `vibe attach <session-id>` / `vibe a <session-id>` | Attach the TUI to a session |
| `vibe server status` | Show background server metadata |
| `vibe server stop` | Stop the background server |
| `vibe storage status` | Show local storage status |
| `vibe search <query>` | Search stored sessions/memory |
| `vibe skill list` | List executable skills |

Attach files with Pi-style `@file` arguments. Text files become context blocks; image files become semantic multimodal content for direct prompts and TUI/web session prompts.

```bash
vibe --direct @path/to/image.png "describe this"
vibe --direct "summarize @README.md"
vibe
# then type: compare @lib/foo.ex and @test/foo_test.exs
```

## Server, TUI, and web console

Normal `vibe` invocations are clients. They connect to a singleton background Vibe server, creating it when needed, and attach to server-owned sessions. This gives a tmux-like workflow:

```bash
# terminal 1
vibe

# terminal 2
vibe

# terminal 3
vibe a <session-id>
```

The Phoenix LiveView web console uses the same session processes as the TUI. `vibe --web` starts the background server when needed, prints an authenticated URL, and opens the browser. Token-based local authentication protects the console.

Foreground server commands are available for debugging:

```bash
vibe server start --foreground
vibe server restart --foreground
```

## Eval as the control plane

The model-facing tool surface stays small. Most project-aware power is exposed through Elixir APIs available from `eval`.

Common aliases:

- `Cmd` — `Vibe.Command`, supervised shell commands with persisted output
- `MD` — `Vibe.MD`, Markdown rendering helpers
- `Web` — provider-neutral web search/fetch API
- `Goal` — active session goal controls

Examples:

```elixir
Cmd.run(["mix", "test"], timeout: 120_000) |> MD.doc()
Vibe.Telemetry.summary()
Vibe.Session.list()
Vibe.Storage.status()
Vibe.Context.recall("sqlite migration", cwd: File.cwd!(), limit: 3)
Web.search!("ecto sqlite fts", num_results: 5, highlights: true) |> MD.doc()
```

Prefer these APIs over raw `System.cmd/3`, ad-hoc string formatting, and provider-specific web clients.

## Storage and search

Runtime state lives under `~/.vibe` by default. The main database is `~/.vibe/vibe.db`.

```bash
vibe storage status
vibe storage migrate
vibe search "sqlite migration" --cwd vibe
vibe storage search "sqlite migration" --cwd vibe --include-tools
vibe storage import pi path/to/pi-session.jsonl --rebuild-fts
```

Important local files:

```text
~/.vibe/vibe.db                 # SQLite database for durable state
~/.vibe/auth.json               # ChatGPT/Codex OAuth credentials
~/.vibe/server.json             # background server metadata
~/.vibe/server.out              # background server log
~/.vibe/web-token               # web console auth token
~/.vibe/agent-profiles.toml     # model/role/plugin configuration
~/.vibe/skills/                 # user skill files
~/.vibe/rules/                  # system prompt rule files
```

Use environment variables to isolate dev/test instances:

```bash
VIBE_HOME=/tmp/vibe-dev
VIBE_DB_PATH=/tmp/vibe-dev/vibe.db
VIBE_SESSION_DIR=/tmp/vibe-sessions
```

## Subagents, plugins, and skills

Subagents are supervised jobs. LLM subagents create child Vibe sessions that can be attached like any other session.

```elixir
{:ok, job} = Vibe.Subagents.start("Research ReqLLM OpenRouter support", role: :scout)
Vibe.Subagents.await(job.id)
Vibe.Subagents.result(job.id)
```

Built-in plugins currently include:

- **Rules** — loads `~/.vibe/rules/*.md` into the system prompt with optional model-glob filtering
- **Safety** — asks for confirmation before risky commands
- **Notify** — terminal notifications when tasks complete or fail
- **Question** — model-facing question tool with selectable options
- **WebSearch** — provider-neutral web search/fetch through the `Web` eval alias

Disable plugins in `~/.vibe/agent-profiles.toml`:

```toml
disabled_plugins = ["notify", "safety"]
```

Executable skills are trusted local Elixir files discovered from `priv/skills`, `./skills`, `./.vibe/skills`, and `~/.vibe/skills`.

```bash
vibe skill list
vibe skill show <name>
vibe skill apis
vibe skill from-session <session-id> <name>
```

## Providers and models

Vibe passes `provider:model` strings through ReqLLM. Most providers authenticate with environment variables such as `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or provider-specific keys. Codex/OpenAI OAuth is available through:

```bash
vibe --login codex
```

Model switching supports fuzzy names and reasoning-effort shorthand:

```bash
vibe --model anthropic:claude-sonnet-4-5-20250929
/model claude-sonnet:high
/effort medium
```

## Built-in help

Task-focused docs are available from the CLI:

```bash
vibe help
vibe help quickstart
vibe help eval
vibe help ast
vibe help lsp
vibe help sessions
vibe help slash-commands
vibe help subagents
vibe help plugins
vibe help storage
vibe help memory
vibe help web
vibe help gateways
vibe help troubleshooting
```

The TUI exposes the same docs through `/help`.

## Install from checkout

Use a checkout when developing Vibe itself or testing unreleased changes:

```bash
git clone https://github.com/elixir-vibe/vibe.git
cd vibe
mix deps.get
mix ci
```

Run from the checkout:

```bash
mix vibe
mix vibe --help
```

Install a local `vibe` executable:

```bash
mix vibe.install
```

## Development

Run the full gate:

```bash
mix ci
```

`mix ci` runs compile, format check, tests, Credo, Dialyzer, ExDNA, and Reach smell checks.

Useful checks from Elixir:

```elixir
report = Vibe.Code.Checks.analyze()
report.ok?
report.failures
Vibe.SelfPatch.deployment_gate()
```

## First principles

1. Few model-facing tools outside; many BEAM powers inside.
2. Prefer `eval` over shelling out to `mix run`.
3. Prefer AST-aware search/replace for Elixir syntax.
4. Use LSP for diagnostics/navigation and runtime eval for OTP state.
5. Subagents, plugins, sessions, terminal panes, and background work are OTP processes.
6. UI state is semantic; terminal and web rendering are adapters.
7. Persist durable state with Ecto schemas/migrations and typed semantic events.
8. Self-improvement changes skills/helpers first; runtime core changes need tests and validation.
