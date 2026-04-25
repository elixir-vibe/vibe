defmodule Exy.TUI.RendererTest do
  use ExUnit.Case, async: true

  test "renders semantic view model to width-safe styled lines" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp/project", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:user_message_added, "s1", %{text: String.duplicate("hello ", 20)})
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_message_added, "s1", %{text: "ok"})
      )

    lines = state |> Exy.UI.ViewModel.from_state() |> Exy.TUI.Renderer.render(40)
    plain_lines = Enum.map(lines, &Exy.TUI.Width.visible_text/1)

    assert Enum.all?(plain_lines, &(String.length(&1) <= 40))
    assert Enum.any?(plain_lines, &String.starts_with?(&1, "  hello"))
    assert ("  ok" <> String.duplicate(" ", 36)) in plain_lines
    refute Enum.any?(plain_lines, &String.starts_with?(&1, "You: "))
    refute Enum.any?(plain_lines, &String.starts_with?(&1, "Exy: "))
    assert Enum.any?(lines, &(IO.iodata_to_binary(&1) =~ "\e[48;2;37;39;47m"))
    assert Enum.any?(lines, &(IO.iodata_to_binary(&1) =~ "\e[48;2;27;29;34m"))
  end
end
