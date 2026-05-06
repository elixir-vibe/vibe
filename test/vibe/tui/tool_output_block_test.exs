defmodule Vibe.TUI.ToolOutputBlockTest do
  use ExUnit.Case, async: true

  alias Vibe.Tool.Display
  alias Vibe.TUI.{Theme, ToolOutputBlock, Width}

  test "renders text, inspect, source, diff, markdown, and lines blocks" do
    display = %Display{
      body: [
        {:text, "plain", []},
        {:inspect, "%{ok: true}", []},
        {:source, "defmodule Demo do\nend", language: "elixir"},
        {:diff, "+ 1  added", language: "elixir"},
        {:markdown, "**bold**", []},
        {:lines, [["custom"]], []}
      ],
      truncate?: false
    }

    rendered = ToolOutputBlock.display_body_lines(display, 80, Theme.default())
    plain = Enum.map_join(rendered, "\n", &Width.visible_text/1)
    ansi = IO.iodata_to_binary(rendered)

    assert plain =~ "plain"
    assert plain =~ "%{ok: true}"
    assert plain =~ "defmodule Demo"
    assert plain =~ "added"
    assert plain =~ "bold"
    assert plain =~ "custom"
    assert ansi =~ "\e[38;2;"
  end

  test "returns nil for empty display bodies" do
    assert is_nil(ToolOutputBlock.display_body_lines(%Display{body: []}, 80, Theme.default()))
  end

  test "adds truncation hints for long text" do
    text = Enum.map_join(1..12, "\n", &"line #{&1}")

    rendered =
      ToolOutputBlock.display_body_lines(
        %Display{body: [{:text, text, []}], truncate?: true},
        80,
        Theme.default()
      )

    plain = Enum.map_join(rendered, "\n", &Width.visible_text/1)

    assert plain =~ "more lines"
  end

  test "adds read-limit footer when source was externally truncated" do
    rendered =
      ToolOutputBlock.display_body_lines(
        %Display{body: [{:source, "line", read_limit_truncated?: true}], truncate?: false},
        80,
        Theme.default()
      )

    plain = Enum.map_join(rendered, "\n", &Width.visible_text/1)
    assert plain =~ "file truncated by read limit"
  end
end
