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

  test "renders mermaid flowcharts through boxart" do
    lines =
      """
      ```mermaid
      graph LR
        A[Start] --> B[Done]
        A -- yes --> C[Ship]
      ```
      """
      |> Markdown.render(80, Theme.default())

    plain = Enum.map_join(lines, "\n", &Width.visible_text/1)

    assert plain =~ "Start"
    assert plain =~ "Done"
    assert plain =~ "Ship"
    assert plain =~ "yes"
    refute plain =~ "```"
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

  test "does not render trailing quoted blank lines at the end of blockquotes" do
    plain =
      "> quote\n\nnext"
      |> Markdown.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    quote_index = Enum.find_index(plain, &String.contains?(&1, "quote"))
    next_index = Enum.find_index(plain, &(&1 == "next"))

    assert Enum.at(plain, quote_index + 1) == ""

    refute Enum.any?(
             Enum.slice(plain, (quote_index + 1)..(next_index - 1)//1),
             &(String.trim(&1) == "│")
           )
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

  test "pads emoji table cells by terminal width" do
    plain =
      """
      | Emoji | Text |
      |---|---|
      | 🚀 | rocket |
      | ⚗️ | alembic |
      | 東 | CJK |
      """
      |> Markdown.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    table_lines = Enum.filter(plain, &String.starts_with?(&1, "│"))

    assert Enum.map(table_lines, &Width.visible_length/1) ==
             List.duplicate(19, length(table_lines))

    assert Enum.any?(table_lines, &String.contains?(&1, "│ 🚀    │ rocket"))
    assert Enum.any?(table_lines, &String.contains?(&1, "│ ⚗️    │ alembic"))
    assert Enum.any?(table_lines, &String.contains?(&1, "│ 東    │ CJK"))
  end

  test "wraps long table cells instead of silently truncating them" do
    plain =
      """
      | Feature | Description |
      |---|---|
      | Link | [a very long link label](https://example.com/some/really/long/path) with trailing words |
      | Code | `Enum.map([1, 2, 3], &(&1 * 2))` keeps the rest visible |
      """
      |> Markdown.render(48, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.any?(plain, &String.contains?(&1, "https://example.com"))
    assert Enum.any?(plain, &String.contains?(&1, "/some/really/long/pa"))
    assert Enum.any?(plain, &String.contains?(&1, "th) with trailing"))
    assert Enum.any?(plain, &String.contains?(&1, "with trailing"))
    assert Enum.any?(plain, &String.contains?(&1, "words"))
    assert Enum.any?(plain, &String.contains?(&1, "keeps the"))
    assert Enum.any?(plain, &String.contains?(&1, "rest visible"))
  end

  test "streaming table border width stays stable as wider rows arrive" do
    document =
      Markdown.new_stream()
      |> Markdown.put_chunk("| A | B | C |\n")
      |> Markdown.put_chunk("|---|---|---|\n")

    first_top = streaming_table_top(document)

    second_top =
      document
      |> Markdown.put_chunk("| short | medium | long |\n")
      |> streaming_table_top()

    third_top =
      document
      |> Markdown.put_chunk("| much wider content | medium | long |\n")
      |> streaming_table_top()

    assert first_top == second_top
    assert second_top == third_top
  end

  test "renders comprehensive stress fixture without known spacing regressions" do
    plain = render_stress_fixture(120)

    assert Enum.any?(plain, &String.contains?(&1, "Comprehensive Markdown Test Suite"))
    assert Enum.any?(plain, &String.contains?(&1, "│ │ • With a list"))
    assert Enum.any?(plain, &String.contains?(&1, "[ ] Incomplete nested task"))
    assert Enum.any?(plain, &String.contains?(&1, "Code block inside blockquote inside list"))
    assert Enum.any?(plain, &String.contains?(&1, "This is content inside a <details> block."))
    assert Enum.any?(plain, &String.contains?(&1, "f(x) = x^2 + 2x + 1"))
    refute Enum.any?(plain, &String.contains?(&1, "```"))
    refute adjacent_table_tops?(plain)

    assert Enum.count(plain, &String.starts_with?(&1, "╭")) == 2

    quote_index = Enum.find_index(plain, &String.contains?(&1, "Blockquote inside list"))
    next_nested_item_index = Enum.find_index(plain, &String.contains?(&1, "Another nested item"))

    assert Enum.any?(
             Enum.slice(plain, (quote_index + 1)..(next_nested_item_index - 1)//1),
             &(String.trim(&1) == "")
           )

    assert next_nested_item_index > quote_index + 1
  end

  test "streaming comprehensive fixture does not leave duplicate table top borders" do
    "priv/fixtures/markdown_stress.md"
    |> File.stream!([], :line)
    |> Enum.reduce(Markdown.new_stream(), fn chunk, document ->
      document = Markdown.put_chunk(document, chunk)

      plain =
        document
        |> Markdown.render_stream(120, Theme.default())
        |> Enum.map(&Width.visible_text/1)

      refute adjacent_table_tops?(plain)
      assert Enum.count(plain, &String.starts_with?(&1, "╭")) <= 2

      document
    end)
  end

  defp streaming_table_top(document) do
    document
    |> Markdown.render_stream(80, Theme.default())
    |> Enum.map(&Width.visible_text/1)
    |> Enum.find(&String.starts_with?(&1, "╭"))
  end

  defp render_stress_fixture(width) do
    "priv/fixtures/markdown_stress.md"
    |> File.read!()
    |> Markdown.render(width, Theme.default())
    |> Enum.map(&Width.visible_text/1)
  end

  defp adjacent_table_tops?(lines) do
    lines
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.any?(fn [left, right] ->
      String.starts_with?(left, "╭") and String.starts_with?(right, "╭")
    end)
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
