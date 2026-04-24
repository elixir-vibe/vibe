# Exy Agent Guidelines

- Keep the model-facing tool count minimal.
- Add Exy helper modules callable from `Exy.Eval` instead of adding narrow external tools.
- Use `Exy.AST`/ExAST for Elixir syntax search, replace, and diff. Do not use grep for code structure.
- Use OTP supervision for background work and subagents.
- Self-improvement should prefer skills and helper modules before changing runtime core.
- Before self-modification, add/update tests for intended behavior, run `Exy.SelfPatch.preflight/1`, then patch.
- Validate self-patches through `Exy.Checks.run_all/1`: format, compile, ExUnit, Credo, ExSlop, ExDNA, and Reach. Prefer Elixir APIs over shelling out to Mix tasks.
