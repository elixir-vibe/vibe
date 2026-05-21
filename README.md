# Vibe

BEAM-native coding agent for Elixir/OTP projects.

Vibe gives you an interactive terminal agent, a Phoenix LiveView web console, and a background session server that all run as supervised BEAM processes. It is designed for Elixir codebases where the agent should inspect runtime state, use project APIs, keep durable local history, and stay attachable/cancellable like any other OTP workload.

If you are new, start with the Hex install below, run `vibe`, and use `/help` inside the TUI.

## Quick start

Install the released executable:

```bash
mix escript.install hex vibe
export PATH="$HOME/.mix/escripts:$PATH"
```

Sign in with ChatGPT/Codex if you want to use Codex/OpenAI OAuth:

```bash
vibe --login codex
```

Start the TUI:

```bash
vibe
```

Open the web console from another terminal or from inside the TUI:

```bash
vibe --web
# or type /web in the TUI
```

Run one prompt without opening the TUI:

```bash
vibe -p "Inspect this project and suggest next steps"
```

Useful first commands inside the TUI:

```text
/help        Show built-in docs
/model       Pick a model and effort
/sessions    Browse sessions
/new         Start another session
/goal TASK   Keep a persistent goal for long-running work
```

Requirements: Elixir 1.19+, Erlang/OTP 27+, and whichever provider credentials your selected model needs. Vibe stores local runtime state under `~/.vibe` by default.

## What Vibe is

Vibe is an OTP application, terminal client, background session server, web console, and coding-agent runtime. It keeps the model-facing tool surface small while exposing Elixir APIs for commands, eval, storage, telemetry, subagents, plugins, AST, and LSP.

Vibe is useful when you want an agent that can:

- work inside a real Elixir runtime instead of treating the project as files plus shell commands;
- keep sessions, eval state, memory, telemetry, subagent jobs, and tool output in durable SQLite storage;
- attach multiple TUI/web clients to the same server-owned session;
- run supervised commands and subagents that can be cancelled, inspected, and resumed;
- expose plugins and project helpers through Elixir APIs rather than adding many narrow model tools.

Good fit: Elixir/OTP projects, long-running debugging/refactoring sessions, agent workflows that need runtime introspection, and teams that want local durable state.

Less ideal: quick one-off CLI prompting with no need for BEAM integration, or environments where you cannot run a local SQLite-backed OTP app.

Most coding-agent harnesses wrap an LLM with a CLI, shell access, and a growing list of tools. Vibe treats the BEAM as the runtime boundary: agents, sessions, subagents, plugins, command jobs, telemetry, eval state, storage, and UI updates are supervised Elixir processes with durable local state and runtime introspection.

## Why Vibe

Vibe is for people who want a coding agent that feels native to Elixir/OTP instead of bolted on from the outside.

- **Small model-facing tool surface, rich eval APIs.** The model sees `read`, `write`, `edit`, `eval`, `ast`, and `lsp`; `eval` exposes pipeable Elixir APIs such as `Cmd`, `MD`, `Vibe.Telemetry`, `Vibe.Storage`, `Vibe.Subagents`, plugins, and project helpers.
- **OTP-native sessions and background work.** Agent sessions, command jobs, subagents, plugin workers, terminal panes, and schedulers are supervised processes that can be monitored, cancelled, restarted, attached to, and inspected.
- **Server-owned sessions.** Vibe supports a tmux-like workflow where sessions live in a background server and clients can create, send to, list, and attach to them.
- **Semantic UI state.** The TUI and Phoenix LiveView web console consume `Vibe.UI.State` events and commands. Terminal rendering and HTML rendering are adapters, not the source of truth.
- **BEAM introspection as an agent capability.** Agents can inspect Vibe's own processes, telemetry, storage, eval state, jobs, and sessions through Elixir APIs.
- **Plugins as OTP extensions.** Plugins can add supervised children, slash commands, eval APIs, semantic UI updates, model-facing actions, and Markdown renderers.
- **Durable local state.** Sessions, trajectory events, UI events, eval snapshots, curated memory, imports, subagent jobs, schedules, and telemetry live in local SQLite through Ecto.

Vibe focuses on making agent work observable, attachable, cancellable, composable, and durable using normal Elixir/OTP runtime patterns.

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

`mix vibe.install` builds the escript, installs it with `mix escript.install --force`, and prints the exact PATH line to add when the Mix escripts directory is not already available. For standard Elixir installs this is usually:

```bash
export PATH="$HOME/.mix/escripts:$PATH"
```

Then run:

```bash
vibe
vibe --help
```

## Common commands

Start and attach sessions:

```bash
vibe new
vibe n
vibe sessions
vibe ls
vibe send <session-id> "Run tests and summarize failures"
vibe attach <session-id>
vibe a <session-id>
```

Attach files with Pi-style `@file` arguments. Text files become `<file name="...">...</file>` context blocks; image files become semantic multimodal content for direct prompts and TUI/Web session prompts.

```bash
vibe --direct @path/to/image.png "describe this"
vibe --direct "summarize @README.md"
vibe
# then type: compare @lib/foo.ex and @test/foo_test.exs
```

Image files read by the agent are available through `read`, resized through pluggable command backends (`magick`, `sips`, `vips`) when needed, and large payloads are stored as session artifacts instead of being duplicated in JSON logs. In the TUI, `Ctrl+V` can paste a clipboard PNG into the composer as an `@path` marker when `pngpaste` is installed.

## Web console

The Phoenix LiveView web console starts automatically on port 4321. Open it with:

```bash
vibe --web                  # opens browser with auth token
/web                        # from TUI: opens browser
```

The web console shares sessions with the TUI in real time — both attach to the same `Vibe.Session` process. Token-based authentication protects access.

## Agent dashboard

Background sessions and manage multiple agents from one screen:

```bash
vibe --bg "fix the flaky test"    # start a headless background session
/bg                                # background the current TUI session
←                                  # on empty prompt: open agent dashboard
```

The dashboard shows all sessions with status, preview, and model. Arrow keys navigate, Space peeks, Enter attaches, Esc returns.

## Providers

Any `provider:model` string works — Vibe passes through to ReqLLM which supports 50+ providers. Most authenticate via env vars (`ANTHROPIC_API_KEY`, `DEEPSEEK_API_KEY`, etc.). OAuth providers (Codex) have dedicated wrappers.

```bash
vibe --model anthropic:claude-sonnet-4
/model claude-sonnet:high           # fuzzy matching + effort shorthand
```

## Core workflows

### Eval as the control plane

Use `eval` for BEAM introspection, supervised commands, Markdown rendering, plugin APIs, and small stateful investigations.

```elixir
Cmd.run(["mix", "test"], timeout: 120_000) |> MD.doc()
Vibe.Telemetry.summary()
Vibe.Session.list()
Vibe.Storage.status()
Vibe.Subagents.ask("Review this module", role: :reviewer)
Web.search!("ecto sqlite fts", num_results: 5, highlights: true) |> MD.doc()
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", format: :html) |> Web.select!("main") |> MD.doc()
```

`Cmd` is `Vibe.Command`, `MD` is `Vibe.MD`, and `Web` is Vibe's provider-neutral web search/fetch API. Prefer them over raw `System.cmd/3`, ad-hoc string formatting, and provider-specific web clients.

### Local storage and search

Runtime state lives under `~/.vibe` by default. The main database is `~/.vibe/vibe.db`.

```bash
vibe storage status
vibe storage migrate
vibe storage search "sqlite migration" --cwd vibe
```

```elixir
Vibe.Storage.status()
Vibe.Storage.Search.query("sqlite migration", scopes: [:sessions, :memory], cwd: "vibe")
Vibe.Context.recall("sqlite migration", cwd: "vibe", limit: 3)
```

### Subagents

Subagents are supervised jobs. LLM subagents create child Vibe sessions that can be attached like any other session.

```elixir
{:ok, job} = Vibe.Subagents.start("Research ReqLLM OpenRouter support", role: :scout)
Vibe.Subagents.await(job.id)
Vibe.Subagents.result(job.id)
```

```bash
vibe a <job.child_session_id>
```

### Plugins and skills

Plugins are OTP modules under `Vibe.Plugins.*` that extend Vibe through the `Vibe.Plugin` behaviour. Built-in plugins:

- **Rules** — loads `~/.vibe/rules/*.md` into the system prompt with optional model-glob filtering
- **Safety** — blocks destructive commands (PR create, force push, sudo, DROP TABLE) with a TUI confirmation selector
- **Notify** — desktop notifications via OSC terminal escape sequences when tasks complete or fail
- **Question** — model-facing `question` tool that pauses execution and shows options to the user
- **WebSearch** — provider-neutral web search and fetch via the `Web` eval alias

Disable plugins in `~/.vibe/agent-profiles.toml`:

```toml
disabled_plugins = ["notify", "safety"]
```

Plugin API callbacks: `system_prompt/2`, `before_command/3`, `tool_call/3`, `tool_result/3`, `context/3`, `actions/1`, `commands/1`, `apis/1`, `children/1`.

Executable skills are trusted local Elixir files discovered from `priv/skills`, `./skills`, `./.vibe/skills`, and `~/.vibe/skills`.

```bash
vibe skill list
vibe skill show <name>
vibe skill apis
vibe skill from-session <session-id> <name>
```

## Built-in help

Task-focused docs are available from the CLI:

```bash
vibe help
vibe help quickstart
vibe help eval
vibe help sessions
vibe help slash-commands
vibe help subagents
vibe help plugins
vibe help storage
vibe help memory
vibe help web
vibe help troubleshooting
```

The TUI also exposes help through slash commands:

```text
/help
/help eval
```

Module docs describe exact Elixir API contracts. Built-in help is for operational usage while working inside Vibe.

## Runtime files

```text
~/.vibe/vibe.db                 # SQLite database for durable Vibe state
~/.vibe/auth.json              # ChatGPT/Codex OAuth credentials
~/.vibe/server.cookie          # Erlang distribution cookie
~/.vibe/server.json            # server node metadata
~/.vibe/server.out             # background server log
~/.vibe/sessions/<id>.log      # dependency/session log output
~/.vibe/skills/                # user skill files
~/.vibe/rules/                 # system prompt rule files
~/.vibe/tls/                   # TLS certificates for trusted remote distribution
~/.vibe/ssh/                   # OTP SSH daemon host keys
~/.vibe/web-token              # web console auth token
~/.vibe/web-secret-key-base    # Phoenix secret key
~/.vibe/known-nodes.json       # trusted remote Vibe nodes
~/.vibe/agent-profiles.toml    # model/role/plugin configuration
```

Use environment variables to isolate dev/test instances:

```bash
VIBE_HOME=/tmp/vibe-dev
VIBE_DB_PATH=/tmp/vibe-dev/vibe.db
VIBE_SESSION_DIR=/tmp/vibe-sessions
```

## Slash commands

Type `/` in the TUI to open command autocomplete.

```text
/sessions  Browse and attach sessions
/new       Start a new session
/attach ID Attach by session id
/model     Choose model (supports fuzzy matching + model:effort shorthand)
/skill     Choose skill
/branch    Branch session from an earlier message
/bg        Background current session and open agent dashboard
/web       Open web console in browser
/clear     Clear visible messages
/compact   Compact context (token-based cut point)
/commands  Command palette
/help      Open built-in docs
```

Plugins can contribute commands by returning modules that implement `Vibe.UI.SlashCommands.Command` from `Vibe.Plugin.commands/1`.

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
3. Prefer `ast` over regex search for Elixir syntax.
4. Use LSP for diagnostics/navigation and runtime eval for OTP state.
5. Subagents, plugins, sessions, terminal panes, and background work are OTP processes.
6. UI state is semantic; terminal rendering is an adapter.
7. Persist durable state with Ecto schemas/migrations and typed semantic events.
8. Self-improvement changes skills/helpers first, runtime core only with tests and validation.
