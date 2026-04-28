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

  test "footer includes streaming token preview" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:usage_updated, "s1", %{total_tokens: 7}))
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:user_message_added, "s1", %{text: "hello"}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_delta, "s1", %{text: "streaming text"})
      )

    assert Exy.UI.ViewModel.from_state(state).footer.usage.total_tokens == 13
  end

  test "shows a working loader for a running tool even without assistant stream" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "s1",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "read")
        )
      )

    assert [
             %Exy.UI.Block.ToolCall{id: "tool-1"},
             %Exy.UI.Block.AssistantMessage{loader_label: "Working"}
           ] = Exy.UI.ViewModel.from_state(state).body
  end

  test "labels the loader as working while a local tool is running" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "s1", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "s1",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "eval")
        )
      )

    assert [_, %Exy.UI.Block.AssistantMessage{loader_label: "Working"}] =
             Exy.UI.ViewModel.from_state(state).body
  end

  test "uses explicit working messages for the loader" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "s1", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:working_message_updated, "s1", %{message: "Indexing"})
      )

    assert [%Exy.UI.Block.AssistantMessage{loader_label: "Indexing"}] =
             Exy.UI.ViewModel.from_state(state).body
  end

  test "keeps tool calls between surrounding assistant text blocks" do
    state =
      Exy.UI.State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "s1", %{}))
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_delta, "s1", %{text: "Before."}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "s1",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "eval")
        )
      )
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_delta, "s1", %{text: "After."}))

    assert [
             %Exy.UI.Block.AssistantMessage{text: "Before."},
             %Exy.UI.Block.ToolCall{id: "tool-1"},
             %Exy.UI.Block.AssistantMessage{text: "After."}
           ] = Exy.UI.ViewModel.from_state(state).body
  end
end
