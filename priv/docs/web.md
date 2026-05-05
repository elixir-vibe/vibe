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

Fetch defaults to a local `Req` provider. Put network/provider concerns in request options:

```elixir
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html",
  format: :html,
  timeout: 30_000
)
```

Put local content transformations in pipes:

```elixir
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", format: :html)
|> Web.select!("main")
|> MD.doc()
```

Markdown rendering belongs to the `Exy.Markdown` protocol. Use `MD.doc/1` or `MD.to_markdown/1`; do not add renderer-specific `Web.markdown/1` helpers.

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

Use `Web.parse_html!/1` when you need direct Floki traversal:

```elixir
Web.fetch!("https://hexdocs.pm/ecto/Ecto.html", format: :html)
|> Web.parse_html!()
|> Floki.find("main h2")
|> Enum.map(&Floki.text/1)
```

Common extraction should use `Web.select!/2` so selector metadata stays with the fetch result. Advanced traversal can use Floki directly after `Web.parse_html!/1`.

The LiveView console renders image tool results semantically. Inline images use `data:` URLs, while large image reads are copied to session artifacts and displayed through local artifact URLs such as:

```text
/sessions/<session-id>/artifacts/images/<file>.png
```

Artifact-backed previews include an “Open original” link.

The session composer accepts inline image references such as:

```text
describe @screenshots/login.png
```

Image references are converted into semantic prompt content before dispatch. The transcript keeps the user's original text and shows an attachment badge, while the model request receives image content parts.

Orphan artifact directories can be cleaned with:

```bash
exy sessions prune --artifacts
```

Do not put secrets or authorization headers into telemetry metadata. Pass custom fetch headers only when required.
