defmodule Exy.UI.ViewModelTest do
  use ExUnit.Case, async: true

  test "builds semantic blocks from state" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:user_message_added, "s1", %{text: "hello"}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_message_added, "s1", %{text: "hi"})
      )
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:usage_updated, "s1", %{total_tokens: 7}))

    view = Exy.UI.ViewModel.from_state(state)

    assert [%Exy.UI.Block.UserMessage{}, %Exy.UI.Block.AssistantMessage{}] = view.body
    assert view.footer.session_id == "s1"
    assert view.footer.usage.total_tokens == 7
  end
end
