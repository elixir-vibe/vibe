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

Exy keeps the model-facing tool surface small:

- `read`
- `edit` / `write`
- `bash` / terminal
- `elixir_eval` → `Exy.Eval.run/2`
- `elixir_ast` → `Exy.AST.run/1`
- `elixir_lsp` → `Exy.LSP.run/1`

Everything else is normal Elixir callable from `elixir_eval`:

- `Exy.OTP` — process, ETS, supervision, runtime introspection
- `Exy.Profile` — `:cprof`, `:eprof`, `:fprof`, process-growth helpers
- `Exy.Subagents` — supervised subagent process runner
- `Exy.Skill` — procedural-memory skill files
- `Exy.Trajectory` — structured event capture for self-improvement
- `Exy.Session` — persisted JSONL dialogs, events, and usage under `~/.exy/sessions`
- `Exy.LLM.Usage` — normalized token/cost accounting from model responses
- `Exy.Context` — pi-style context compaction checkpoints
- `Exy.Runtime` / `Exy.Script` — Livebook-inspired standalone BEAM runtime and Mix.install script runner
- `Exy.Sandbox.Policy` — explicit isolation policy data for runtime selection
- `Exy.Checks` — format/compile/test/Credo/ExSlop/ExDNA/Reach validation gates
- `Exy.SelfPatch` — validated development hot-compile helpers
- `Exy.LLM` — direct ReqLLM calls
- `Exy.Agent` / `Exy.Agent.Coding` — Jido.AI ReAct agent over Exy's three Elixir tools
- `Exy.Auth` / `Exy.Auth.Codex` — behaviour-based auth providers and ChatGPT/Codex OAuth
- `Exy.Plugin` — behaviour-based plugin hooks discovered from `Exy.Plugins.*`
- `Exy.UI` — UI-neutral event/state/command layer for TUI and future LiveView clients
- `Exy.Terminal` — Ghostty-backed terminal panes and terminal-aware snapshots
- `Exy.Python` / `Exy.JS` — optional Pythonx and QuickBEAM evaluation helpers

## First principles

1. Few tools outside, many BEAM powers inside.
2. Prefer `elixir_eval` over shelling out to `mix run`.
3. Prefer `elixir_ast` over grep for Elixir syntax.
4. Use LSP for diagnostics/navigation, runtime eval for OTP state.
5. Subagents are OTP processes, not prompt magic.
6. Self-improvement evolves skills/helpers first, runtime core only with validation.
7. Tests come before self-modification; `Exy.Checks.run_all/1` gates reloads.

## Examples

```elixir
Exy.Eval.run("Exy.OTP.runtime_info()")

Exy.AST.run(%{
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

# Direct LLM call through ReqLLM
Exy.LLM.ask("Summarize Exy's architecture")

# Elixir API: Jido-backed agent
{:ok, pid} = Exy.start_link()
Exy.ask(pid, "Use elixir_eval to inspect runtime info")
Exy.Session.list()

# CLI / Mix task
#   mix exy
#   mix exy -p "Inspect runtime info"
#   mix exy --eval "Exy.OTP.runtime_info()"
#   mix exy --compact --keep-recent 20
#   mix exy --checks
#   mix exy --codex-usage
#   mix exy --sessions
#   mix exy --session work-1 -p "Continue this persisted session"
#   mix exy --login codex

# Expert LSP gateway
Exy.LSP.run(%{action: :diagnostics, file: "lib/exy.ex"})

# Self inspection and validation
Exy.supervision_tree(depth: 2)
report = Exy.Checks.analyze()
report.ok?
report.failures
Exy.Checks.analyze(checks: [:test, :ex_slop])
Exy.SelfPatch.deployment_gate()
Exy.SelfPatch.compile_and_reload()

# Livebook-style standalone runtime
{:ok, runtime} = Exy.Runtime.start_link()
Exy.Runtime.evaluate(runtime, "Mix.install([])\nx = 1 + 2")
Exy.Runtime.evaluate(runtime, "x * 2")
Exy.Runtime.stop(runtime)

# One-shot scripts with Mix.install/2
Exy.Script.run_string("Mix.install([])\nIO.puts(:ok)")
Exy.Script.run_string("x = 1 + 2", runtime: :standalone)

# Optional Python/JS helpers through Pythonx and QuickBEAM
Exy.Python.run("x = 1 + 2\nx", %{})
Exy.JS.run("1 + 2")

# UI-neutral session state for TUI and future LiveView clients
{:ok, ui} = Exy.UI.SessionServer.start_link()
Exy.UI.SessionServer.subscribe(ui)
Exy.UI.SessionServer.dispatch(ui, {:open_overlay, %{kind: :session_selector}})
Exy.UI.SessionServer.state(ui)

# Ghostty terminal panes and snapshots
{:ok, pane} = Exy.Terminal.Pane.start_link(cmd: "/bin/sh")
Exy.Terminal.Pane.write(pane, "echo hello\\n")
Exy.Terminal.Pane.snapshot(pane)
Exy.Terminal.Snapshot.from_ansi("\\e[32mok\\e[0m\\r\\n")

# Semantic TUI theming maps to ANSI now and CSS variables later
view = Exy.UI.SessionServer.state(ui) |> Exy.UI.ViewModel.from_state()
Exy.TUI.Renderer.render(view, 100, Exy.TUI.Theme.default())
```
