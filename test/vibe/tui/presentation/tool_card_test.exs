defmodule Vibe.TUI.Presentation.ToolCardTest do
  use ExUnit.Case, async: true

  alias Vibe.Terminal.{Theme, Width}
  alias Vibe.TUI.Presentation.ToolCard

  test "renders title with tool name, summary, metadata, and success icon" do
    title =
      ToolCard.title(%{name: :eval, status: :ok}, 80, Theme.default(),
        summary: "1 + 1",
        meta: ["2ms"]
      )

    plain = Width.visible_text(title)

    assert plain =~ "eval"
    assert plain =~ "1 + 1"
    assert plain =~ "2ms"
    assert plain =~ "✓"
  end

  test "ellipsizes title summary to available width" do
    title =
      ToolCard.title(%{name: :eval, status: :running}, 24, Theme.default(),
        summary: String.duplicate("long ", 20),
        meta: ["metadata"]
      )

    assert Width.visible_length(title) <= 24
  end

  test "normalizes success status and colors status backgrounds" do
    assert ToolCard.status(%{status: :success}) == :ok
    assert IO.iodata_to_binary(ToolCard.status_icon(:error, Theme.default())) =~ "×"
    assert IO.iodata_to_binary(ToolCard.status_bg("ok", :ok, Theme.default())) =~ "\e[48;2;"
  end

  test "wraps title and sections in inset card lines" do
    lines = ToolCard.block(%{name: :read, status: :ok}, 20, Theme.default(), [["body"]])

    assert length(lines) == 2
    assert Enum.all?(lines, &(Width.visible_length(&1) <= 20))
  end
end
