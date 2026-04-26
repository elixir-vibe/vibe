# Exy

Minimal BEAM-native coding-agent substrate.

## Install

```elixir
{:exy, "~> 0.1.0"}
```

Or run from this repository:

```bash
mix exy --help
```

Install a local `exy` executable from a checkout:

```bash
mix escript.install --force
```

Make sure Mix's escript directory is on your `PATH` (Mix prints the exact install path; commonly `~/.mix/escripts`):

```bash
export PATH="$HOME/.mix/escripts:$PATH"
```

Then run:

```bash
exy --help
exy
```

By default, `exy` behaves like a small tmux-style client: it starts the Exy background server when needed, creates or resumes the latest server-owned session, and attaches the TUI. Closing the TUI detaches the client; the server-owned session remains available for later `exy attach`.

Exy keeps the model-facing tool surface small:

- `read`
- `edit` / `write`
- `bash` / terminal
- `eval` → `Exy.Eval.run/2`
- `ast` → `Exy.Code.AST.run/1`
- `lsp` → `Exy.Code.LSP.run/1`

Everything else is normal Elixir callable from `eval`:

- `Exy.OTP` — process, ETS, supervision, runtime introspection
- `Exy.Profile` — `:cprof`, `:eprof`, `:fprof`, process-growth helpers
- `Exy.Subagents` — supervised subagent process runner
- `Exy.Skill` — procedural-memory skill files
- `Exy.Trajectory` — structured event capture for self-improvement
- `Exy.Session` — persisted JSONL dialogs, events, and usage under `~/.exy/sessions`
- `Exy.Agent.Usage` — normalized token/cost accounting from model responses
- `Exy.Context` — pi-style context compaction checkpoints
- `Exy.Runtime` / `Exy.Runtime.Standalone` / `Exy.Script` — runtime behaviour, standalone BEAM evaluator, and Mix.install script runner
- `Exy.Sandbox.Policy` — explicit isolation policy data for runtime selection
- `Exy.Code.Checks` — format/compile/test/Credo/ExSlop/ExDNA/Reach validation gates
- `Exy.SelfPatch` — validated development hot-compile helpers
- `Exy.Agent` / `Exy.Agent.Coding` — Jido.AI ReAct agent over Exy's coding tools
- `Exy.Auth` / `Exy.Auth.Codex` — behaviour-based auth providers and ChatGPT/Codex OAuth
- `Exy.Plugin` — behaviour-based plugin hooks discovered from `Exy.Plugins.*`
- `Exy.UI` — UI-neutral event/state/command layer for TUI and future LiveView clients
- `Exy.Terminal` — Ghostty-backed terminal panes and terminal-aware snapshots
- `Exy.Runtime.Python` / `Exy.Runtime.JS` — optional Pythonx and QuickBEAM evaluation helpers

## First principles

1. Few tools outside, many BEAM powers inside.
2. Prefer `eval` over shelling out to `mix run`.
3. Prefer `ast` over grep for Elixir syntax.
4. Use LSP for diagnostics/navigation, runtime eval for OTP state.
5. Subagents are OTP processes, not prompt magic.
6. Self-improvement evolves skills/helpers first, runtime core only with validation.
7. Tests come before self-modification; `Exy.Code.Checks.run_all/1` gates reloads.

## Examples

```elixir
Exy.Eval.run("Exy.OTP.runtime_info()")

Exy.Code.AST.run(%{
  action: :search,
  path: "lib/",
  pattern: "def handle_call(_, _, _) do _ end"
})

Exy.Subagents.run_many([
  %{role: :static, goal: "Count modules", run: fn _ -> length(Path.wildcard("lib/**/*.ex")) end},
  %{role: :runtime, goal: "Runtime info", run: fn _ -> Exy.OTP.runtime_info() end}
])

# ChatGPT/Codex OAuth
Exy.Auth.login("codex")
Exy.Auth.ensure_fresh("openai-codex")
Exy.Auth.usage("openai-codex")

# Elixir API: Jido-backed agent
{:ok, pid} = Exy.start_link()
Exy.ask(pid, "Use eval to inspect runtime info")
Exy.Session.list()

# CLI / Mix task
#   mix exy
#   exy server start
#   exy server status
#   exy server stop
#   exy new
#   exy sessions
#   exy send <session-id> "Inspect runtime info"
#   exy attach <session-id>
#   mix exy -p "Inspect runtime info"
#   mix exy --eval "Exy.OTP.runtime_info()"
#   mix exy --compact --keep-recent 20
#   mix exy --checks
#   mix exy --codex-usage
#   mix exy --sessions
#   mix exy --session work-1 -p "Continue this persisted session"
#   mix exy --login codex

# Expert LSP gateway
Exy.Code.LSP.run(%{action: :diagnostics, file: "lib/exy.ex"})

# Self inspection and validation
Exy.supervision_tree(depth: 2)
report = Exy.Code.Checks.analyze()
report.ok?
report.failures
Exy.Code.Checks.analyze(checks: [:test, :ex_slop])
Exy.SelfPatch.deployment_gate()
Exy.SelfPatch.compile_and_reload()

# Livebook-style standalone runtime
{:ok, runtime} = Exy.Runtime.Standalone.start_link()
Exy.Runtime.Standalone.evaluate(runtime, "Mix.install([])\nx = 1 + 2")
Exy.Runtime.Standalone.evaluate(runtime, "x * 2")
Exy.Runtime.Standalone.stop(runtime)

# One-shot scripts with Mix.install/2
Exy.Script.run_string("Mix.install([])\nIO.puts(:ok)")
Exy.Script.run_string("x = 1 + 2", runtime: :standalone)

# Optional Python/JS helpers through Pythonx and QuickBEAM
Exy.Runtime.Python.run("x = 1 + 2\nx", %{})
Exy.Runtime.JS.run("1 + 2")

# UI-neutral session state for TUI and LiveView-compatible clients
{:ok, ui} = Exy.Session.start_link()
{:ok, snapshot, cursor} = Exy.Session.attach(ui)
Exy.Session.dispatch(ui, {:open_overlay, %{kind: :session_selector}})
Exy.Session.state(ui)

# Ghostty terminal panes and snapshots
{:ok, pane} = Exy.Terminal.Pane.start_link(cmd: "/bin/sh")
Exy.Terminal.Pane.write(pane, "echo hello\\n")
Exy.Terminal.Pane.snapshot(pane)
Exy.Terminal.Snapshot.from_ansi("\\e[32mok\\e[0m\\r\\n")

# Semantic TUI theming maps to ANSI now and CSS variables later
view = Exy.Session.state(ui) |> Exy.UI.ViewModel.from_state()
Exy.TUI.Renderer.render(view, 100, Exy.TUI.Theme.default())
```

## Server sessions

Server mode keeps canonical session state in supervised BEAM processes. TUI clients, scripts, and the future web client attach to those sessions over Erlang distribution.

```bash
exy server start          # start background server
exy server status         # check metadata and distribution reachability
exy server stop           # stop the server
exy new                   # create a server-owned session
exy sessions              # list live and persisted sessions
exy send <id> "prompt"    # send work without attaching a TUI
exy attach <id>           # attach a TUI client
```

Runtime files:

```text
~/.exy/server.cookie      # Exy-specific Erlang distribution cookie
~/.exy/server.json        # server node metadata
~/.exy/server.out         # background server log
~/.exy/sessions/<id>.jsonl # canonical append-only session log
~/.exy/sessions/<id>.log   # dependency/session log output
```

The JSONL session log stores typed entries, including semantic UI events, so `Exy.Session.attach/3` can rebuild snapshots and replay missed events from durable state.
