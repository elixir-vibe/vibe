# LSP

Use the `lsp` tool for language-server-backed code intelligence: definitions, references, hover, diagnostics, symbols, and code actions.

## Common actions

- `diagnostics` — file diagnostics.
- `workspace_diagnostics` — project diagnostics.
- `definition` — jump to the definition at a position.
- `references` — find references for a symbol at a position.
- `hover` — show type/docs information at a position.
- `symbols` and `workspace_symbols` — inspect available symbols.
- `actions` — list or apply code actions.

## Guidelines

- Prefer LSP for semantic navigation and diagnostics.
- Prefer `ast` for syntax-shaped search and mechanical rewrites.
- Position-based actions need a ready language server and accurate 1-based line/column positions.
- If a language server is still indexing, retry diagnostics or symbols after it reports readiness.

## Example

```elixir
%{action: "definition", file: "lib/example.ex", line: 12, column: 8}
```
