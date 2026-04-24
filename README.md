# Exy

Minimal BEAM-native coding-agent substrate.

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
- `Exy.SelfPatch` — development hot-compile helpers
- `Exy.LLM` — direct ReqLLM calls
- `Exy.Agent` / `Exy.Agent.Coding` — Jido.AI ReAct agent over Exy's three Elixir tools
- `Exy.Auth.Codex` — ChatGPT/Codex OAuth login compatible with pi's flow
- `Exy.TUI.Terminal` — minimal Ghostty-backed terminal pane primitive

## First principles

1. Few tools outside, many BEAM powers inside.
2. Prefer `elixir_eval` over shelling out to `mix run`.
3. Prefer `elixir_ast` over grep for Elixir syntax.
4. Use LSP for diagnostics/navigation, runtime eval for OTP state.
5. Subagents are OTP processes, not prompt magic.
6. Self-improvement evolves skills/helpers first, runtime core only with validation.

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
Exy.Auth.Codex.login()
Exy.Auth.Codex.ensure_fresh()

# Direct LLM call through ReqLLM
Exy.LLM.ask("Summarize Exy's architecture", model: "openai:gpt-4o-mini")

# Elixir API: Jido-backed agent
{:ok, pid} = Exy.start_link(model: "openai:gpt-4o-mini")
Exy.ask(pid, "Use elixir_eval to inspect runtime info")

# CLI / Mix task
#   mix exy
#   mix exy -p "Inspect runtime info"
#   mix exy --eval "Exy.OTP.runtime_info()"
#   mix exy --compact --keep-recent 20
#   mix exy --login codex

# Expert LSP gateway
Exy.LSP.run(%{action: :diagnostics, file: "lib/exy.ex"})

# Ghostty terminal primitive
{:ok, pane} = Exy.TUI.Terminal.start(cmd: "/bin/sh")
Exy.TUI.Terminal.write(pane, "echo hello\\n")
Exy.TUI.Terminal.pump_once(pane)
Exy.TUI.Terminal.snapshot(pane)
```
