# Docs TODO

## Done

- Split Exy documentation by reader intent:
  - `README.md` now focuses on first-time orientation, positioning, install, first run, core workflows, built-in help pointers, runtime files, slash-command summary, and development gate.
  - `priv/docs/*.md` now contains task-focused built-in docs for users already inside Exy.
  - Key module docs now carry API/runtime contracts instead of product overview text.
- Added built-in docs runtime:
  - `Exy.Docs`
  - `exy help`
  - `exy help <topic>`
  - `exy docs <topic>`
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
- Added or strengthened module docs for:
  - `Exy.Eval`
  - `Exy.Command`
  - `Exy.Session`
  - `Exy.Subagents`
  - `Exy.Plugin`
  - `Exy.UI.State`
  - `Exy.Storage.Search`
- Added coverage for docs/help behavior:
  - `test/exy/docs_test.exs`
  - `test/exy/cli/help_test.exs`
  - `test/exy/ui/slash_commands/help_test.exs`
- Validation completed:
  - `mix test test/exy/docs_test.exs test/exy/cli/help_test.exs test/exy/ui/slash_commands/help_test.exs test/exy/ui/autocomplete_test.exs test/exy/ui/reducer_test.exs test/exy/cli/sessions_test.exs`
  - `MIX_ENV=prod mix compile --warnings-as-errors`
- Committed as `b41712e Add built-in Exy docs`.

## Follow-up

- Wire `/help` into a richer TUI document/modal view if notification rendering is too cramped for longer topics.
- Add built-in docs for `auth`, `models`, `lsp`, `ast`, and `terminal-panes` once those workflows stabilize.
- Keep README concise; move detailed operational docs to `priv/docs/*.md` and exact API contracts to module docs.
- When adding new slash commands or CLI workflows, update both the relevant built-in doc topic and the focused module docs.
