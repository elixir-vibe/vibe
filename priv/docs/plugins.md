# Plugins

Plugins are supervised Elixir extensions. They can add runtime children, eval APIs, slash commands, model-facing actions, semantic UI updates, and Markdown rendering.

A plugin can expose APIs to eval:

```elixir
Exy.Plugin.Manager.apis()
Web.search!("ecto sqlite fts", num_results: 5, highlights: true)
|> Web.filter_domain("hexdocs.pm")
|> MD.doc()

Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", selector: "main", format: :markdown)
|> MD.doc()
```

Plugins can update renderer-neutral UI state:

```elixir
Exy.Plugin.UI.set_status(session_id, :indexer, "indexing")
Exy.Plugin.UI.set_progress(session_id, :indexer, title: "Indexing", current: 1, total: 10)
Exy.Plugin.UI.set_widget(session_id, :panel, ["line 1", "line 2"], placement: :below_editor)
```

Plugins can render their own structs by implementing `Exy.Markdown`, or by exposing `to_markdown/1` on runtime-loaded structs handled by the fallback renderer.

Executable skills are trusted local Elixir files. Review executable skill code before sharing or installing it.
