# Web Markdown TODO

## Current state

- `Exy.WebTools.HTML.to_markdown/1` is a deliberately small Floki-tree HTML-to-Markdown renderer.
- It exists to keep `MD.doc(Web.fetch!(..., format: :html) |> Web.select!(...))` usable while the standalone `turndown` package is built.
- It does not parse HTML with regular expressions; Floki owns parsing and CSS selection.
- It handles the common shape needed by Exy now: headings, paragraphs, links, emphasis, code/pre, blockquotes, nested lists, basic tables, images, hr/br, and ignored script/style-like tags.

## Follow-up direction

- Build `/Users/dannote/Development/turndown_ex` into a pure-Elixir Hex package named `turndown`.
- Port Turndown's rule architecture and borrow node-html-markdown's readability/spacing goals.
- Keep Floki for parsing/tree input.
- Replace Exy's small renderer with the package once it is good enough.

## Do not regress

- Do not add `Web.markdown/1` or renderer-like `Web.as_text/1` helpers.
- Rendering still belongs to `Exy.Markdown` via `MD.doc/1` / `MD.to_markdown/1`.
- Do not parse HTML with regex or ad-hoc string stripping.
- Keep request/provider concerns in `Web.fetch/2` options and local transformations in pipe helpers like `Web.select!/2` and `Web.truncate/2`.

## Minimum replacement fixture

The standalone package should at least match this output:

````markdown
# Title

Hello [link](/x).

> Quote

- One
- Two
  - Nested

| A | B |
| --- | --- |
| 1 | 2 |

```
mix test
```
````
