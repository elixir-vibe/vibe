# Eval

`eval` runs Elixir inside Vibe's runtime. Use it for BEAM introspection, helper APIs, supervised commands, Markdown rendering, plugin APIs, and small stateful investigations.

Use the smallest execution layer that fits:

| Layer | Use for |
|---|---|
| `Vibe.Eval.run/2` | In-process runtime inspection and session-persistent helper state |
| `Vibe.Eval.once/2` | One-off in-process evaluation |
| `Vibe.ScriptRuntime.Standalone` | Isolated child BEAM for `Mix.install/2` experiments |
| `Vibe.Script` | Disposable scripts |

Eval sessions preload useful aliases:

- `Cmd` — `Vibe.Command`, supervised OS commands.
- `MD` — `Vibe.MD`, Markdown rendering for UI/tool output.
- Plugin aliases such as `Web` when plugins are enabled.

Examples:

```elixir
Cmd.run(["mix", "test"], timeout: 120_000) |> MD.doc()
Vibe.Telemetry.summary()
Vibe.Session.list()
Vibe.Storage.status()
Vibe.Subagents.ask("Review this module", role: :reviewer)
Web.search!("ecto sqlite fts", num_results: 5, highlights: true) |> MD.doc()
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", format: :html) |> Web.select!("main") |> MD.doc()
```

`Web` is provider-neutral. Exa is the default search provider and a local `Req` implementation is the default fetch provider; future providers can implement the same behaviours without changing eval code.

Stateful eval with a session id preserves variables, aliases, imports, and requires:

```elixir
Vibe.Eval.run(~s(query = "sqlite fts"), session_id: session_id)
Vibe.Eval.run(~s(query <> " migration"), session_id: session_id)
Vibe.Eval.bindings(session_id)
Vibe.Eval.reset(session_id)
```

Image files are available through the normal `Image` eval alias and model content APIs:

```elixir
image = Image.from_file!("screenshot.png", resize?: true)
Vibe.Model.Direct.ask([
  Vibe.Model.Content.text("Describe this image"),
  Vibe.Model.Content.image(data: image.data, mime_type: image.mime_type, filename: image.filename)
])
```

Use `mix run scripts/image_model_smoke.exs` to verify the configured multimodal provider against a labeled fixture. Interactive TUI and Web prompts also accept inline image references such as `describe @screenshot.png`; Vibe keeps the visible prompt text unchanged while passing image content semantically through the session and model request pipeline.

Prefer `Cmd.run/2` and `Cmd.start/2` over raw `System.cmd/3`; command jobs are supervised and expose status/output/cancellation APIs.

Prefer `MD.doc/1` when a value should render as Markdown in Vibe. Use `MD.to_markdown/1` only when you need the raw Markdown string.
