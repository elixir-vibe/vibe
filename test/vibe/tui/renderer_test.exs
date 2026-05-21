defmodule Vibe.TUI.RendererTest do
  use ExUnit.Case, async: true

  test "renders semantic view model to width-safe styled lines" do
    state =
      Vibe.UI.State.new(session_id: "s1", cwd: "/tmp/project", model: "openai_codex:gpt-5.5")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.Event.new(:user_message_added, "s1", %{text: String.duplicate("hello ", 20)})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.Event.new(:assistant_message_added, "s1", %{text: "ok"})
      )

    lines = state |> Vibe.UI.ViewModel.from_state() |> Vibe.TUI.Renderer.render(40)
    plain_lines = Enum.map(lines, &Vibe.TUI.Width.visible_text/1)

    assert Enum.all?(plain_lines, &(String.length(&1) <= 40))
    assert Enum.any?(plain_lines, &String.starts_with?(&1, "  hello"))
    assert ("  ok" <> String.duplicate(" ", 36)) in plain_lines
    refute Enum.any?(plain_lines, &String.starts_with?(&1, "You: "))
    refute Enum.any?(plain_lines, &String.starts_with?(&1, "Vibe: "))
    assert Enum.any?(lines, &(IO.iodata_to_binary(&1) =~ "\e[48;2;37;39;47m"))
    assert Enum.any?(lines, &(IO.iodata_to_binary(&1) =~ "\e[48;2;27;29;34m"))
  end
end
