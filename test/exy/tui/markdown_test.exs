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

    assert plain =~ "Title\n─"
    assert plain =~ "Some bold and italic and code."
    assert plain =~ "elixir"
    assert plain =~ "IO.puts(:ok)"
    refute plain =~ "```"
    assert plain =~ "╭───┬───╮"
    assert plain =~ "│ A │ B │"
  end

  test "adds vertical rhythm between markdown blocks" do
    plain =
      "First paragraph\n\nSecond paragraph"
      |> Markdown.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert plain == ["First paragraph", "", "Second paragraph"]
  end

  test "syntax highlights fenced code with terminal ANSI" do
    lines = Markdown.render("```elixir\nIO.puts(:ok)\n```", 80, Theme.default())
    rendered = IO.iodata_to_binary(lines)

    assert rendered =~ "\e[38;2;"
  end

  test "renders blank highlighted code lines" do
    lines = Markdown.render("```elixir\n\n:ok\n```", 80, Theme.default())
    plain = Enum.map(lines, &Width.visible_text/1)

    assert Enum.any?(plain, &(String.trim(&1) == ":ok"))
  end

  test "renders partial streaming markdown with temporary closures" do
    doc = Markdown.new_stream() |> Markdown.put_chunk("**bo")

    plain =
      doc
      |> Markdown.render_stream(40, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert plain =~ "bo"
  end

  test "renders task list items, including incomplete streaming task markers" do
    plain =
      "- [x]\n- [ ] todo"
      |> Markdown.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "[x]"))
    assert Enum.any?(plain, &String.contains?(&1, "[ ] todo"))
  end
end
