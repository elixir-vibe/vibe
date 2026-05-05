# AST

Use the `ast` tool when textual search is too brittle and the task depends on Elixir syntax structure.

## Common actions

- `search` — find one AST pattern.
- `search_many` — find several patterns in one pass.
- `replace` — rewrite code by AST pattern.
- `diff` — preview structural edits before writing.

## Guidelines

- Prefer narrow patterns and paths.
- Use `search_many` for independent probes instead of several separate searches.
- Keep `allow_broad` disabled unless a repository-wide syntax scan is intentional.
- Review replacement diffs before applying broad rewrites.

## Examples

```elixir
%{action: "search", pattern: "IO.inspect(_)", path: "lib"}
```

```elixir
%{
  action: "search_many",
  patterns: ["dbg(_)", "IO.inspect(_)"],
  path: "lib",
  limit: 50
}
```
