# Exy Agent Guidelines

- Keep the model-facing tool count minimal.
- Add Exy helper modules callable from `Exy.Eval` instead of adding narrow external tools.
- Use `Exy.AST`/ExAST for Elixir syntax search, replace, and diff. Do not use grep for code structure.
- Use OTP supervision for background work and subagents.
- Self-improvement should prefer skills and helper modules before changing runtime core.
- Before self-modification, add/update tests for intended behavior, run `Exy.SelfPatch.preflight/1`, then patch.
- Validate self-patches through `Exy.Checks.analyze/1` first; use the returned `report.failures` instead of rerunning checks with different inspect/options. Prefer Elixir APIs over shelling out to Mix tasks.
- Prefer idiomatic OTP/Elixir APIs over ad-hoc path/process handling, e.g. `Application.app_dir/2` for priv files and Erlang `:code.soft_purge/1`/`:code.delete/1`/`:code.ensure_loaded/1` for hot reload.
- Keep prompts in `priv/prompts/*.md` and embed them at compile time through `Exy.Prompts` with `@external_resource`.
- Avoid static catalogs/registries when modules can be discovered idiomatically from compiled application modules or dependency availability, like Reach/Volt plugin detection.
- Design APIs for agents to use comfortably: return structured, compact, actionable maps with summaries and failure details in one call.
- Auth, plugins, runtimes, and providers should be behaviour-based so future implementations can be added without changing callers.
- TUI rendering should stay semantic and iodata-first; avoid raw markdown markers/fences when rendering Markdown widgets.
- Use MDEx streaming documents for partial LLM Markdown and Lumis terminal highlighting for fenced code blocks instead of hand-rolled parsers/highlighters.
- Storybook output is a visual regression surface; inspect it after changing TUI/Markdown rendering, not just tests.
- For Livebook-style execution and `Mix.install/2`, isolate work in a child BEAM/runtime; do not pollute Exy's long-running VM.
