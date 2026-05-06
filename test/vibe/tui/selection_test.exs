defmodule Vibe.TUI.SelectionTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI

  alias Vibe.TUI.{Theme, Widget, Width}

  test "renders windowed select list without scrollbars" do
    lines =
      TUI.select_list(
        title: "Models",
        items: Enum.map(1..20, &"model-#{&1}"),
        selected: 10,
        limit: 5
      )
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert hd(lines) == "  Models                              "
    assert length(lines) == 7
    assert Enum.any?(lines, &String.contains?(&1, "model-11"))
    refute Enum.any?(lines, &String.contains?(&1, "█"))
  end

  test "renders notifications" do
    plain =
      TUI.notifications(items: [%{level: :warning, text: "rate limit soon"}])
      |> Widget.render(40, Theme.default())
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert plain =~ "rate limit soon"
  end
end
