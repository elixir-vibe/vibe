# Vibe

BEAM-native coding agent for Elixir/OTP projects.

Vibe is a terminal/web coding agent that runs as a local OTP application. It includes a TUI, a LiveView web console, persistent sessions, plugins, skills, subagents, and project-aware Elixir eval.

> [!WARNING]
> Vibe is experimental and not production-ready. It can take actions on your machine and talk to external model providers. Use it at your own risk, review changes before applying them, and avoid repositories or machines where unintended agent actions would be costly.

## Why Vibe?

Vibe is an experiment in making an agent feel native to the BEAM, rather than wrapping a chat loop around shell commands.

A few things this gives you:

- **Elixir eval as the control plane.** The agent can use stateful Elixir APIs for commands, storage, search, telemetry, goals, web fetches, Markdown rendering, and custom helpers. The model sees a small tool surface, but the agent still gets a composable interface.
- **Stateful work, closer to Livebook.** Eval sessions can keep intermediate values around, so the agent can compute something once, inspect it, transform it, and refer back to it later.
- **OTP supervision for agent work.** Sessions, command jobs, plugin workers, subagents, telemetry, UI state, and storage are supervised processes that can be monitored, cancelled, resumed, and inspected.
- **Agents can launch other agents.** Subagents get their own sessions and lifecycle, which makes parallel research, background work, and longer workflows easier to model.
- **Remote workflows are part of the design.** Vibe can use SSH and Erlang distribution so agents can attach to remote nodes and coordinate across machines.
- **The system is meant to be customized.** Plugins, skills, gateways, semantic events, and eval helpers are extension points. During development, Vibe can run checks, patch code, and hot-reload modules; tools like Reach help keep boundaries clear.

## Quick start

Requirements: Elixir 1.19+, Erlang/OTP 27+, and credentials for the model provider you select. Vibe stores local runtime state under `~/.vibe` by default.

Package docs are on [HexDocs](https://hexdocs.pm/vibe/).

Install the released executable from Hex:

```bash
mix escript.install hex vibe
export PATH="$HOME/.mix/escripts:$PATH"
```

Sign in with ChatGPT/Codex OAuth if you use the Codex/OpenAI provider:

```bash
vibe --login codex
```

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

## Useful commands

The README only shows the common paths. For the full command reference, run `vibe --help` or see [`Mix.Tasks.Vibe`](https://hexdocs.pm/vibe/Mix.Tasks.Vibe.html).

| Command | Purpose |
| --- | --- |
| `vibe` | Start/attach the TUI |
| `vibe --web [--port 4321]` | Open the LiveView console |
| `vibe -p "prompt"` | Run a prompt and exit |
| `vibe --bg "prompt"` | Start a background session |
| `vibe new` / `vibe n` | Create and attach a fresh session |
| `vibe sessions` / `vibe ls` | List recent sessions |
| `vibe attach [session-id]` / `vibe a [session-id]` | Attach the TUI to a session |
| `vibe subagents jobs` | List subagent jobs |
| `vibe connect [--ssh\|--dist] <target>` | Save a remote Vibe node |

Attach files with Pi-style `@file` arguments. Text files become context blocks. Image files are supported by direct prompts and by inline `@image` references in the TUI/web prompt.

```bash
vibe --direct @path/to/image.png "describe this"
vibe --direct "summarize @README.md"
vibe
# then type: compare @lib/foo.ex and @test/foo_test.exs
```

## Server, TUI, and web console

Normal `vibe` invocations are clients. They connect to a singleton background Vibe server, creating it when needed. This gives a tmux-like workflow:

```bash
# terminal 1
vibe

# terminal 2
vibe

# terminal 3
vibe a <session-id>
```

The Phoenix LiveView web console uses the same session processes as the TUI. `vibe --web` prints an authenticated URL and opens the browser.

Foreground server commands are available for debugging:

```bash
vibe server start --foreground
vibe server restart --foreground
```

## Eval APIs

Most project-aware power is exposed through Elixir APIs available from [`eval`](https://hexdocs.pm/vibe/Vibe.Eval.html).

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

Prefer these APIs over raw `System.cmd/3`, ad-hoc string formatting, and provider-specific web clients when working inside Vibe.

## Storage and search

Runtime state lives under `~/.vibe` by default and is stored in local SQLite. Sessions, eval snapshots, memory, telemetry, subagent jobs, and imported history can be searched from the CLI or eval.

```bash
vibe storage status
vibe search "sqlite migration" --cwd vibe
vibe storage import pi path/to/pi-session.jsonl --rebuild-fts
```

See `vibe help storage`, [`Vibe.Storage`](https://hexdocs.pm/vibe/Vibe.Storage.html), and [`Vibe.Storage.Search`](https://hexdocs.pm/vibe/Vibe.Storage.Search.html) for migration, FTS, and isolation options.

## Subagents, plugins, and skills

[`Vibe.Subagents`](https://hexdocs.pm/vibe/Vibe.Subagents.html) creates child Vibe sessions that can be attached like any other session.

```elixir
{:ok, job} = Vibe.Subagents.start("Review the storage search code")
Vibe.Subagents.await(job.id)
Vibe.Subagents.result(job.id)
```

From the CLI:

```bash
vibe subagents jobs
vibe subagents status <job-id>
vibe subagents result <job-id>
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
vibe --model openai_codex:gpt-5.5
/model openai_codex:gpt-5.5:high
/effort medium
```

## Built-in help

API docs are available on [HexDocs](https://hexdocs.pm/vibe/). Task-focused docs are available from the CLI:

```bash
vibe help
vibe help eval
vibe help subagents
vibe help storage
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

`mix ci` runs compile, format check, tests, Credo, Dialyzer, ExDNA, and Reach checks.

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
