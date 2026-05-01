# Web

Exy exposes provider-neutral web search and fetch APIs to eval through the `Web` alias.

Search defaults to the Exa provider when `EXA_API_KEY` is set:

```elixir
Web.search!("OpenAI Responses WebSocket agent loop",
  type: :deep,
  num_results: 5,
  highlights: true,
  summary: true
)
|> MD.doc()
```

Fetch defaults to a local `Req` provider:

```elixir
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html",
  selector: "main",
  format: :markdown
)
|> MD.doc()
```

Supported fetch formats:

```elixir
:markdown
:text
:html
:json
```

Search and fetch providers are behaviours, so future backends can share the same eval-facing API:

```elixir
Exy.WebTools.SearchProvider
Exy.WebTools.FetchProvider
```

Per-call provider override:

```elixir
Web.search!("query", provider: :exa)
Web.fetch!("https://example.com", provider: :req)
```

Provider-specific details are normalized into `Exy.WebTools.SearchResult`, `Exy.WebTools.SearchItem`, and `Exy.WebTools.FetchResult` structs with Markdown protocol rendering.

Do not put secrets or authorization headers into telemetry metadata. Pass custom fetch headers only when required.
