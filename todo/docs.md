# Docs TODO

## Done

- Split Vibe documentation by reader intent:
  - `README.md` now focuses on first-time orientation, positioning, install, first run, core workflows, built-in help pointers, runtime files, slash-command summary, and development gate.
  - `priv/docs/*.md` now contains task-focused built-in docs for users already inside Vibe.
  - Key module docs now carry API/runtime contracts instead of product overview text.
- Added built-in docs runtime:
  - `Vibe.Docs`
  - `vibe help`
  - `vibe help <topic>`
  - `vibe docs <topic>`
  - `/help`
  - `/help <topic>`
- Added built-in doc topics:
  - `quickstart`
  - `eval`
  - `sessions`
  - `slash-commands`
  - `subagents`
  - `plugins`
  - `storage`
  - `memory`
  - `troubleshooting`
- Added built-in `web` docs after introducing provider-neutral `Web.search/2` and `Web.fetch/2`.
- Added or strengthened module docs for:
  - `Vibe.Eval`
  - `Vibe.Command`
  - `Vibe.Session`
  - `Vibe.Subagents`
  - `Vibe.Plugin`
  - `Vibe.UI.State`
  - `Vibe.Storage.Search`
- Added coverage for docs/help behavior:
  - `test/vibe/docs_test.exs`
  - `test/vibe/cli/help_test.exs`
  - `test/vibe/ui/slash_commands/help_test.exs`
- Validation completed:
  - `mix test test/vibe/docs_test.exs test/vibe/cli/help_test.exs test/vibe/ui/slash_commands/help_test.exs test/vibe/ui/autocomplete_test.exs test/vibe/ui/reducer_test.exs test/vibe/cli/sessions_test.exs`
  - `MIX_ENV=prod mix compile --warnings-as-errors`
- Committed as `b41712e Add built-in Vibe docs`.

## Follow-up

- Wire `/help` into a richer TUI document/modal view if notification rendering is too cramped for longer topics.
- Add built-in docs for `auth`, `models`, `lsp`, `ast`, and `terminal-panes` once those workflows stabilize.
- Expand `web` docs when additional search/fetch providers are added beyond Exa and Req.
- Keep README concise; move detailed operational docs to `priv/docs/*.md` and exact API contracts to module docs.
- When adding new slash commands or CLI workflows, update both the relevant built-in doc topic and the focused module docs.
