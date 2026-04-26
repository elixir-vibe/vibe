# Exy

BEAM-native coding-agent substrate for Elixir/OTP projects.

Exy is an OTP application, terminal client, background session server, and coding-agent runtime built around a small model-facing tool surface and a large set of native Elixir introspection APIs.

## Highlights

- Tool-capable coding agent backed by Jido/ReqLLM.
- Default model: `openai_codex:gpt-5.5` with ChatGPT/Codex OAuth credentials.
- Minimal model-facing tools:
  - `read`
  - `write`
  - `edit`
  - `eval`
  - `ast`
  - `lsp`
- Semantic UI state shared by TUI and future LiveView clients.
- Ghostty-backed TTY/PTY integration.
- Tmux-like background server and attachable sessions.
- Local SQLite storage at `~/.exy/exy.db` for sessions, UI events, eval state, subagent jobs/schedules, memory, telemetry, and imports.
- Local telemetry recorder with `Exy.Telemetry` self-inspection APIs.
- Plugin system with supervised background children, semantic UI updates, and plugin-registered slash commands.
- Iodata-first terminal widgets, Markdown rendering, and dark/light themes.

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

## CLI overview

Default interactive entrypoints open the TUI and attach to a server-owned session when possible:

```bash
exy
mix exy
exy attach
exy a
```

Server/session commands:

```bash
exy server start
exy server status
exy server stop
exy new
exy n
exy sessions
exy ls
exy send <session-id> "prompt"
exy attach <session-id>
exy a <session-id>
```

Storage commands:

```bash
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
```

Scriptable/non-interactive commands remain available through flags such as:

```bash
mix exy -p "Inspect runtime info"
mix exy --eval "Exy.OTP.runtime_info()"
mix exy --checks
mix exy --codex-usage
mix exy --login codex
```

## Slash commands

The TUI supports behavior-backed slash command modules and command autocomplete.

Built-ins:

```text
/sessions  Browse and attach sessions
/session   Alias for /sessions
/s         Alias for /sessions
/new       Start a new session
/n         Alias for /new
/attach    Open session selector
/attach ID Attach by session id
/a ID      Alias for /attach ID
/model     Choose model
/skill     Choose skill
/clear     Clear visible messages
/compact   Compact context
/commands  Command palette
```

Typing `/` opens generic autocomplete. Plugins can contribute commands by returning modules that implement `Exy.UI.SlashCommand` from `Exy.Plugin.commands/1`.

## Runtime files

Exy keeps runtime state under `~/.exy` by default. Set `EXY_HOME` to isolate a test/dev instance.

```text
~/.exy/exy.db                 # SQLite database for durable Exy state
~/.exy/auth.json              # ChatGPT/Codex OAuth credentials
~/.exy/server.cookie          # Exy-specific Erlang distribution cookie
~/.exy/server.json            # server node metadata
~/.exy/server.out             # background server log
~/.exy/sessions/<id>.log      # dependency/session log output
~/.exy/skills                 # skill files
```

Environment overrides:

```bash
EXY_HOME=/tmp/exy-dev
EXY_DB_PATH=/tmp/exy-dev/exy.db
EXY_SESSION_DIR=/tmp/exy-sessions
```

## Elixir APIs for agents

Everything below is callable through `eval`; prefer these APIs over adding narrow new tools.

### Sessions

```elixir
{:ok, session} = Exy.Session.start(session_id: "work")
{:ok, snapshot, cursor} = Exy.Session.attach(session)
Exy.Session.dispatch(session, {:submit_prompt, %{text: "hello"}})
Exy.Session.detach(session)
Exy.Session.state(session)
Exy.Session.list()
Exy.Session.active_count()
```

Durable session data is backed by local SQLite storage:

```elixir
Exy.Session.Store.list()
Exy.Session.Store.ui_events("work")
Exy.Session.Store.trajectory(session_id: "work")
Exy.Session.search("sqlite migration", session_id: "work")
```

### Storage

Most durable state lives in local SQLite through Ecto schemas, migrations, and `Exy.Repo`:

- sessions and UI events
- trajectory events
- eval state snapshots
- subagent jobs and schedules
- curated memory
- telemetry events
- import records

The default database path is `~/.exy/exy.db`; override it with `EXY_DB_PATH`.

```elixir
Exy.Paths.database()
Exy.Storage.status()
Exy.Storage.migrate!()
Exy.Storage.Import.import_path("pi", "/path/to/pi-session-or-dir", progress: &IO.inspect/1)
Exy.Storage.FTS.status()
Exy.Storage.FTS.rebuild()
Exy.Storage.FTS.optimize()
Exy.Storage.checkpoint!()
Exy.Storage.vacuum!()
Exy.Storage.Search.query("sqlite migration", scopes: [:sessions, :memory], cwd: "exy")
Exy.Context.recall("sqlite migration", cwd: "exy", limit: 3)
```

```bash
exy storage migrate
exy storage status
exy storage fts status
exy storage fts rebuild
exy storage fts optimize
exy storage checkpoint
exy storage vacuum
exy storage search "sqlite migration" --cwd exy
exy storage import pi /path/to/pi-session-or-dir --batch-size 25
```

User-editable config and runtime bootstrap files remain plain files, including agent profiles, auth files, server metadata, server cookie, and per-session dependency logs.

### Telemetry/self-inspection

Exy records selected Exy, ReqLLM, Jido, Finch, and WebSockex telemetry events locally.

```elixir
Exy.Telemetry.path()
Exy.Telemetry.events()
Exy.Telemetry.recent()
Exy.Telemetry.recent(100)
Exy.Telemetry.all(limit: 1_000)
Exy.Telemetry.summary()
Exy.Telemetry.clear()
```

Emit custom local telemetry:

```elixir
Exy.Telemetry.execute([:exy, :custom, :event], %{count: 1}, %{source: :eval})

Exy.Telemetry.span([:exy, :custom, :work], %{name: :demo}, fn ->
  :ok
end)
```

OpenTelemetry is available in-process. Exy disables external span processors by default so no external collector is required. ReqLLM's OpenTelemetry bridge is attached when OTel is available; exporting elsewhere can be enabled later by configuring normal OpenTelemetry processors/exporters.

### Coding helpers

```elixir
Exy.Code.AST.run(%{action: :search, path: "lib/", pattern: "def handle_call(_, _, _) do _ end"})
Exy.Code.LSP.run(%{action: :diagnostics, file: "lib/exy.ex"})
Exy.Code.Checks.analyze()
Exy.Code.Checks.analyze(checks: [:test, :ex_slop])
```

### Runtime/eval helpers

`eval` is stateful when called with a session id. Normal Elixir variables, aliases, imports, and requires persist for that session. Serializable eval state is snapshotted to the canonical session log and restored without replaying old eval code. Use `Exy.Eval.once/2` for explicit one-off evaluation.

```elixir
Exy.Eval.run(~s(query = "weather in washington"), session_id: session_id)
Exy.Eval.run(~s(query <> " tomorrow"), session_id: session_id)
Exy.Eval.bindings(session_id)
Exy.Eval.forget(session_id, [:query])
Exy.Eval.reset(session_id)
Exy.Eval.once("Exy.OTP.runtime_info()")

{:ok, runtime} = Exy.Runtime.Standalone.start_link()
Exy.Runtime.Standalone.evaluate(runtime, "Mix.install([])\nx = 1 + 2")
Exy.Runtime.Standalone.evaluate(runtime, "x * 2")
Exy.Runtime.Standalone.stop(runtime)

Exy.Script.run_string("Mix.install([])\nIO.puts(:ok)")
Exy.Runtime.Python.run("x = 1 + 2\nx", %{})
Exy.Runtime.JS.run("1 + 2")
```

### Auth, model usage, and agent profiles

```elixir
Exy.Auth.login("codex")
Exy.Auth.login("openrouter", api_key: "sk-or-...")
Exy.Auth.ensure_fresh("openai-codex")
Exy.Auth.ensure_fresh("openrouter")
Exy.Auth.usage("openai-codex")

Exy.Model.Config.default()
Exy.Model.Direct.ask("hello", model: "openai_codex:gpt-5.5")
Exy.Model.Direct.ask("hello", model: "openrouter:anthropic/claude-sonnet-4")

Exy.Agent.Profile.path()
Exy.Agent.Profile.load()
Exy.Agent.Profile.model_for(role: :scout)
Exy.Agent.Profile.provider_options(:openrouter)
```

Agent role/model preferences are editable TOML at `~/.exy/agent-profiles.toml`. Roles are optional profile keys, not hardcoded classes; explicit `model`, `system`, and task opts override role defaults.

### Subagents and schedules

Subagents are supervised jobs. LLM subagents create real child Exy sessions, so their work can be attached like any other session:

```elixir
{:ok, job} = Exy.Subagents.start("Research ReqLLM OpenRouter support", role: :scout)
Exy.Subagents.status(job.id)
Exy.Subagents.await(job.id)
Exy.Subagents.result(job.id)
Exy.Subagents.cancel(job.id)

# Attach from the shell:
# exy a <job.child_session_id>

Exy.Subagents.ask("Summarize this repository", role: :summarizer)

Exy.Subagents.run_many([
  %{role: :scout, task: "Inspect provider docs"},
  %{role: :reviewer, task: "Review the implementation plan"}
])

{:ok, schedule} = Exy.Subagents.schedule("Check telemetry errors", every: :timer.minutes(30))
Exy.Subagents.scheduled()
Exy.Subagents.unschedule(schedule.id)
```

The local scheduler uses OTP timers and persists schedule definitions in SQLite; missed runs are skipped by default. A scheduler backend boundary is planned so hosted/Phoenix deployments can use Oban later without changing the public API.

### Memory

Exy separates session eval state, per-agent runtime memory, and curated long-term memory.

```elixir
Exy.Memory.add(:user, "User prefers concise technical answers")
Exy.Memory.add(:global, "For Exy, run mix ci before commits")
Exy.Memory.search("mix ci", scopes: [:user, :global])
Exy.Memory.context_block("validation", scopes: [:user, :global])

Exy.Agent.Memory.put(agent_id, :plan, "inspect docs")
Exy.Agent.Memory.get(agent_id, :plan)
Exy.Agent.Memory.clear(agent_id)

Exy.Memory.Manager.prefetch("validation command", %{session_id: session_id})
Exy.Memory.Manager.on_delegation("research task", "summary", %{parent_session_id: session_id})
```

Built-in memory is always active; at most one external memory provider should be loaded at a time to avoid conflicting recall/tool surfaces. Recalled memory is fenced as `<memory-context>` and treated as informational background, not user input.

### Plugins

```elixir
defmodule MyPlugin do
  use Exy.Plugin

  @impl true
  def children(_state, context), do: []

  @impl true
  def commands(_state), do: [MyPlugin.HelloCommand]

  @impl true
  def apis(_state) do
    [
      %Exy.Plugin.API{
        name: :hello,
        module: MyPlugin.API,
        alias: Hello,
        description: "Composable helper API for eval sessions"
      }
    ]
  end
end

defmodule MyPlugin.HelloCommand do
  @behaviour Exy.UI.SlashCommand

  @impl true
  def spec, do: %{name: "hello", description: "Say hello"}

  @impl true
  def run(_args, ui_state) do
    {:events, [Exy.UI.Event.new(:notification_added, ui_state.session_id, %{level: :info, text: "hello"})]}
  end
end
```

Plugin APIs are discoverable and pre-aliased in eval sessions. Built-in WebSearch exposes a pipeable Exa-backed `Web` API when `EXA_API_KEY` is set:

```elixir
Exy.Plugin.Manager.apis()
Hello.some_function("input")

Web.search("ecto sqlite fts", num_results: 5, highlights: true)
|> Web.filter_domain("hexdocs.pm")
|> Web.format()
```

Plugins can update renderer-neutral UI state:

```elixir
Exy.Plugin.UI.set_status(session_id, :indexer, "indexing")
Exy.Plugin.UI.set_progress(session_id, :indexer, title: "Indexing", current: 1, total: 10)
Exy.Plugin.UI.set_widget(session_id, :panel, ["line 1", "line 2"], placement: :below_editor)
```

### Terminal panes

```elixir
{:ok, pane} = Exy.Terminal.Pane.start_link(cmd: "/bin/sh")
Exy.Terminal.Pane.write(pane, "echo hello\n")
Exy.Terminal.Pane.snapshot(pane)
Exy.Terminal.Snapshot.from_ansi("\e[32mok\e[0m\r\n")
```

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
