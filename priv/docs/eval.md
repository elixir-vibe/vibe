# Eval

`eval` runs Elixir inside Exy's runtime. Use it for BEAM introspection, helper APIs, supervised commands, Markdown rendering, plugin APIs, and small stateful investigations.

Use the smallest execution layer that fits:

| Layer | Use for |
|---|---|
| `Exy.Eval.run/2` | In-process runtime inspection and session-persistent helper state |
| `Exy.Eval.once/2` | One-off in-process evaluation |
| `Exy.Runtime.Standalone` | Isolated child BEAM for `Mix.install/2` experiments |
| `Exy.Script` | Disposable scripts |

Eval sessions preload useful aliases:

- `Cmd` — `Exy.Command`, supervised OS commands.
- `MD` — `Exy.MD`, Markdown rendering for UI/tool output.
- Plugin aliases such as `Web` when plugins are enabled.

Examples:

```elixir
Cmd.run(["mix", "test"], timeout: 120_000) |> MD.doc()
Exy.Telemetry.summary()
Exy.Session.list()
Exy.Storage.status()
Exy.Subagents.ask("Review this module", role: :reviewer)
Web.search!("ecto sqlite fts", num_results: 5, highlights: true) |> MD.doc()
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", selector: "main", format: :markdown) |> MD.doc()
```

`Web` is provider-neutral. Exa is the default search provider and a local `Req` implementation is the default fetch provider; future providers can implement the same behaviours without changing eval code.

Stateful eval with a session id preserves variables, aliases, imports, and requires:

```elixir
Exy.Eval.run(~s(query = "sqlite fts"), session_id: session_id)
Exy.Eval.run(~s(query <> " migration"), session_id: session_id)
Exy.Eval.bindings(session_id)
Exy.Eval.reset(session_id)
```

Prefer `Cmd.run/2` and `Cmd.start/2` over raw `System.cmd/3`; command jobs are supervised and expose status/output/cancellation APIs.

Prefer `MD.doc/1` when a value should render as Markdown in Exy. Use `MD.to_markdown/1` only when you need the raw Markdown string.
