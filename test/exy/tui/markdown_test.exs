defmodule Exy.TUI.MarkdownTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{Markdown, Theme, Width}

  test "renders headings, emphasis, code blocks, and tables without markdown fences" do
    lines =
      """
      # Title

      Some **bold** and *italic* and `code`.

      ```elixir
      IO.puts(:ok)
      ```

      | A | B |
      |---|---|
      | 1 | 2 |
      """
      |> Markdown.render(80, Theme.default())

    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)

    assert plain =~ "# Title"
    assert plain =~ "Some bold and italic and code."
    assert plain =~ "elixir"
    assert plain =~ "IO.puts(:ok)"
    refute plain =~ "```"
    assert plain =~ "│ A │ B │"
  end

  test "renders partial streaming markdown with temporary closures" do
    doc = Markdown.new_stream() |> Markdown.put_chunk("**bo")

    plain =
      doc
      |> Markdown.render_stream(40, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert plain =~ "bo"
  end
end
