defmodule Exy.TUI.WidgetsTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.{DSL, Theme, Widget, Width}

  test "renders section, status, model info, dialog, and diff widgets" do
    nodes = [
      DSL.section("Tools", [DSL.text("eval")]),
      DSL.status(title: "Expert", description: "ready", color: :success),
      DSL.model_info(model: "gpt-5.5", provider: "openai_codex", usage: %{total_tokens: 1_200}),
      DSL.dialog("Resume", [DSL.text("session")]),
      DSL.diff(lines: [{:del, "old"}, {:add, "new"}])
    ]

    plain =
      nodes
      |> Enum.flat_map(&Widget.render(&1, 80, Theme.default()))
      |> Enum.map_join("\n", &Width.visible_text/1)

    assert plain =~ "Tools"
    assert plain =~ "Expert ready"
    assert plain =~ "gpt-5.5 via openai_codex"
    assert plain =~ "Resume"
    assert plain =~ "-old"
    assert plain =~ "+new"
  end

  test "dialog keeps right border on every framed row" do
    lines =
      DSL.dialog("Resume", [DSL.text("session")], hint: "enter opens")
      |> Widget.render(40, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert Enum.all?(lines, &(String.length(&1) == 40))

    assert Enum.all?(
             lines,
             &(String.ends_with?(&1, "│") or String.ends_with?(&1, "╮") or
                 String.ends_with?(&1, "╯"))
           )
  end

  test "layout primitives render boxes, padding, horizontal rows, spacers, and truncation" do
    lines =
      DSL.box("Layout", [
        DSL.horizontal([DSL.text("left"), DSL.text("right")]),
        DSL.spacer(),
        DSL.padding([DSL.truncate("abcdef", suffix: "…")], x: 2)
      ])
      |> Widget.render(30, Theme.default())
      |> Enum.map(&Width.visible_text/1)

    assert hd(lines) =~ "Layout"
    assert Enum.any?(lines, &String.contains?(&1, "left"))
    assert Enum.any?(lines, &String.contains?(&1, "right"))
    assert Enum.any?(lines, &String.contains?(&1, "abcdef"))
  end
end
