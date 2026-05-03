# Exy

BEAM-native coding-agent runtime for Elixir/OTP projects.

Exy is an OTP application, terminal client, background session server, and coding-agent runtime. It keeps the model-facing tool surface small while exposing Elixir APIs for commands, eval, storage, telemetry, subagents, plugins, AST, and LSP.

Most coding-agent harnesses wrap an LLM with a CLI, shell access, and a growing list of tools. Exy treats the BEAM as the runtime boundary: agents, sessions, subagents, plugins, command jobs, telemetry, eval state, storage, and UI updates are supervised Elixir processes with durable local state and runtime introspection.

## Why Exy

Exy is for people who want a coding agent that feels native to Elixir/OTP instead of bolted on from the outside.

- **Small model-facing tool surface, rich eval APIs.** The model sees `read`, `write`, `edit`, `eval`, `ast`, and `lsp`; `eval` exposes pipeable Elixir APIs such as `Cmd`, `MD`, `Exy.Telemetry`, `Exy.Storage`, `Exy.Subagents`, plugins, and project helpers.
- **OTP-native sessions and background work.** Agent sessions, command jobs, subagents, plugin workers, terminal panes, and schedulers are supervised processes that can be monitored, cancelled, restarted, attached to, and inspected.
- **Server-owned sessions.** Exy supports a tmux-like workflow where sessions live in a background server and clients can create, send to, list, and attach to them.
- **Semantic UI state.** The TUI and Phoenix LiveView prototype consume `Exy.UI.State` events and commands. Terminal rendering is an adapter, not the source of truth.
- **BEAM introspection as an agent capability.** Agents can inspect Exy's own processes, telemetry, storage, eval state, jobs, and sessions through Elixir APIs.
- **Plugins as OTP extensions.** Plugins can add supervised children, slash commands, eval APIs, semantic UI updates, model-facing actions, and Markdown renderers.
- **Durable local state.** Sessions, trajectory events, UI events, eval snapshots, curated memory, imports, subagent jobs, schedules, and telemetry live in local SQLite through Ecto.

Exy focuses on making agent work observable, attachable, cancellable, composable, and durable using normal Elixir/OTP runtime patterns.

## Install from checkout

```bash
cd ~/Development/exy
mix deps.get
mix ci
```

Run from the checkout:

```bash
mix exy
mix exy --help
```

Install a local `exy` executable:

```bash
mix escript.install --force
export PATH="$HOME/.mix/escripts:$PATH"
```

Then run:

```bash
exy
exy --help
```

## First run

Sign in with ChatGPT/Codex OAuth when needed:

```bash
exy --login codex
```

Start the interactive TUI:

```bash
exy
mix exy
```

Start a fresh server-owned session:

```bash
exy new
exy n
```

List, send to, and attach sessions:

```bash
exy sessions
exy ls
exy send <session-id> "Run tests and summarize failures"
exy attach <session-id>
exy a <session-id>
```

Run a non-interactive prompt:

```bash
exy -p "Inspect this project and suggest next steps"
```

Attach images in direct model mode with `@path` references:

```bash
exy --direct "describe @test/fixtures/images/vision-smoke.png"
mix run scripts/image_model_smoke.exs
```

Image files read by the agent are model-facing through `read`, resized through pluggable command backends (`magick`, `sips`, `vips`) when needed, and large payloads are stored as session artifacts instead of being duplicated in JSON logs.

Open the prototype Phoenix LiveView client:

```bash
exy --web --port 4321
```

## Core workflows

### Eval as the control plane

Use `eval` for BEAM introspection, supervised commands, Markdown rendering, plugin APIs, and small stateful investigations.

```elixir
Cmd.run(["mix", "test"], timeout: 120_000) |> MD.doc()
Exy.Telemetry.summary()
Exy.Session.list()
Exy.Storage.status()
Exy.Subagents.ask("Review this module", role: :reviewer)
Web.search!("ecto sqlite fts", num_results: 5, highlights: true) |> MD.doc()
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", format: :html) |> Web.select!("main") |> MD.doc()
```

`Cmd` is `Exy.Command`, `MD` is `Exy.MD`, and `Web` is Exy's provider-neutral web search/fetch API. Prefer them over raw `System.cmd/3`, ad-hoc string formatting, and provider-specific web clients.

### Local storage and search

Runtime state lives under `~/.exy` by default. The main database is `~/.exy/exy.db`.

```bash
exy storage status
exy storage migrate
exy storage search "sqlite migration" --cwd exy
```

```elixir
Exy.Storage.status()
Exy.Storage.Search.query("sqlite migration", scopes: [:sessions, :memory], cwd: "exy")
Exy.Context.recall("sqlite migration", cwd: "exy", limit: 3)
```

### Subagents

Subagents are supervised jobs. LLM subagents create child Exy sessions that can be attached like any other session.

```elixir
{:ok, job} = Exy.Subagents.start("Research ReqLLM OpenRouter support", role: :scout)
Exy.Subagents.await(job.id)
Exy.Subagents.result(job.id)
```

```bash
exy a <job.child_session_id>
```

### Plugins and skills

Plugins can add supervised workers, slash commands, eval APIs, semantic UI updates, model-facing actions, and Markdown renderers. Executable skills are trusted local Elixir files discovered from `priv/skills`, `./skills`, `./.exy/skills`, and `~/.exy/skills`.

```bash
exy skill list
exy skill show <name>
exy skill apis
exy skill from-session <session-id> <name>
```

## Built-in help

Task-focused docs are available from the CLI:

```bash
exy help
exy help quickstart
exy help eval
exy help sessions
exy help slash-commands
exy help subagents
exy help plugins
exy help storage
exy help memory
exy help web
exy help troubleshooting
```

The TUI also exposes help through slash commands:

```text
/help
/help eval
```

Module docs describe exact Elixir API contracts. Built-in help is for operational usage while working inside Exy.

## Runtime files

```text
~/.exy/exy.db                 # SQLite database for durable Exy state
~/.exy/auth.json              # ChatGPT/Codex OAuth credentials
~/.exy/server.cookie          # Exy-specific Erlang distribution cookie
~/.exy/server.json            # server node metadata
~/.exy/server.out             # background server log
~/.exy/sessions/<id>.log      # dependency/session log output
~/.exy/skills                 # skill files
```

Use environment variables to isolate dev/test instances:

```bash
EXY_HOME=/tmp/exy-dev
EXY_DB_PATH=/tmp/exy-dev/exy.db
EXY_SESSION_DIR=/tmp/exy-sessions
```

## Slash commands

Type `/` in the TUI to open command autocomplete.

```text
/sessions  Browse and attach sessions
/new       Start a new session
/attach ID Attach by session id
/model     Choose model
/skill     Choose skill
/clear     Clear visible messages
/compact   Compact context
/commands  Command palette
/help      Open built-in docs
```

Plugins can contribute commands by returning modules that implement `Exy.UI.SlashCommands.Command` from `Exy.Plugin.commands/1`.

## Development

Run the full gate:

```bash
mix ci
```

`mix ci` runs compile, format check, tests, Credo with ExSlop, Dialyzer, and ExDNA.

Useful checks from Elixir:

```elixir
report = Exy.Code.Checks.analyze()
report.ok?
report.failures
Exy.SelfPatch.deployment_gate()
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
