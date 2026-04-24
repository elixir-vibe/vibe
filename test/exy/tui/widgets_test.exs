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
      |> Enum.map(&Width.visible_text/1)
      |> Enum.join("\n")

    assert plain =~ "Tools"
    assert plain =~ "Expert ready"
    assert plain =~ "gpt-5.5 via openai_codex"
    assert plain =~ "Resume"
    assert plain =~ "-old"
    assert plain =~ "+new"
  end
end
