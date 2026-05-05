# Code Intelligence TODO

## AST

- Expand `ast` examples in built-in docs for `search`, `search_many`, and safe replacements.
- Add semantic diff rendering for AST replacements before writes.
- Add named multi-pattern output so agents can distinguish independent matches from one `search_many` call.
- Keep `allow_broad` explicit for broad tree scans and test that default limits prevent runaway output.

## LSP

- Investigate Expert LSP position-based requests and document required workspace startup/readiness behavior.
- Add readiness checks before position-based actions such as `definition`, `references`, `hover`, and `actions`.
- Improve diagnostics rendering for multi-file workspace diagnostics.
- Add language-specific smoke coverage for Elixir plus at least one non-Elixir LSP path.

## Tool contracts

- Keep code-intelligence tools model-facing but minimal: `ast` for syntax-aware operations and `lsp` for language-server operations.
- Prefer structured result structs and renderer-neutral Markdown/TUI/Web display implementations over ad-hoc maps.
