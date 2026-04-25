path = Path.expand("../priv/fixtures/markdown_stress.md", __DIR__)
markdown = File.read!(path)

markdown
|> Exy.TUI.Markdown.render(100, Exy.TUI.Theme.default())
|> Enum.map_join("\n", &Exy.TUI.Width.visible_text/1)
|> IO.puts()
