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

  test "streaming table does not render top border until a delimiter row arrives" do
    only_header = Markdown.new_stream() |> Markdown.put_chunk("| A | B | C |\n")

    assert only_header
           |> Markdown.render_stream(80, Theme.default())
           |> Enum.map(&Width.visible_text/1)
           |> Enum.all?(&(not String.starts_with?(&1, "╭")))

    with_delimiter = Markdown.put_chunk(only_header, "|---|---|---|\n")

    assert with_delimiter
           |> Markdown.render_stream(80, Theme.default())
           |> Enum.map(&Width.visible_text/1)
           |> Enum.any?(&String.starts_with?(&1, "╭"))
  end

  test "renders comprehensive stress fixture without known spacing regressions" do
    plain =
      "priv/fixtures/markdown_stress.md"
      |> File.read!()
      |> Markdown.render(100, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "Markdown Stress Fixture"))
    assert Enum.any?(plain, &String.contains?(&1, "[ ] Pending nested task"))
    refute Enum.any?(plain, &String.contains?(&1, "```"))

    paragraph_index = Enum.find_index(plain, &String.contains?(&1, "This paragraph belongs"))
    quote_item_index = Enum.find_index(plain, &String.contains?(&1, "2. Ordered item"))

    assert Enum.at(plain, paragraph_index + 1) |> String.trim() == ""
    assert quote_item_index > paragraph_index + 1
  end

  test "preserves spacing between complex nested list items" do
    plain =
      """
      1. Ordered item with paragraph

         This paragraph belongs to the ordered item.
      2. Ordered item with blockquote

         > Quote inside ordered list.
      3. Ordered item with code

         ```elixir
         :ok
         ```
      """
      |> Markdown.render(80, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    paragraph_index = Enum.find_index(plain, &String.contains?(&1, "This paragraph belongs"))
    quote_item_index = Enum.find_index(plain, &String.contains?(&1, "2. Ordered item"))
    quote_index = Enum.find_index(plain, &String.contains?(&1, "Quote inside"))
    code_item_index = Enum.find_index(plain, &String.contains?(&1, "3. Ordered item"))

    assert Enum.at(plain, paragraph_index + 1) |> String.trim() == ""
    assert quote_item_index > paragraph_index + 1
    assert code_item_index > quote_index + 1

    assert Enum.any?(
             Enum.slice(plain, (quote_index + 1)..(code_item_index - 1)//1),
             &(String.trim(&1) == "")
           )
  end
end
