defmodule Vibe.UI.ViewModelTest do
  use ExUnit.Case, async: true

  alias Vibe.UI.Block.{AssistantMessage, ToolCall, UserMessage}
  alias Vibe.Tool.Event, as: ToolEvent
  alias Vibe.UI.{Event, Reducer, State, ViewModel}

  test "builds semantic blocks from state" do
    state =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(Event.new(:user_message_added, "s1", %{text: "hello"}))
      |> Reducer.apply_event(Event.new(:assistant_message_added, "s1", %{text: "hi"}))
      |> Reducer.apply_event(Event.new(:usage_updated, "s1", %{total_tokens: 7}))

    view = ViewModel.from_state(state)

    assert [%UserMessage{}, %AssistantMessage{}] = view.body
    assert view.footer.session_id == "s1"
    assert view.footer.usage.total_tokens == 7
  end

  test "footer includes streaming token preview" do
    state =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(Event.new(:usage_updated, "s1", %{total_tokens: 7}))
      |> Reducer.apply_event(Event.new(:user_message_added, "s1", %{text: "hello"}))
      |> Reducer.apply_event(Event.new(:assistant_delta, "s1", %{text: "streaming text"}))

    assert ViewModel.from_state(state).footer.usage.total_tokens == 13
  end

  test "shows a working loader for a running tool even without assistant stream" do
    state =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(
        Event.new(
          :tool_started,
          "s1",
          ToolEvent.started(id: "tool-1", name: "read")
        )
      )

    assert [
             %ToolCall{id: "tool-1"},
             %AssistantMessage{loader_label: "Working"}
           ] = ViewModel.from_state(state).body
  end

  test "labels the loader as working while a local tool is running" do
    state =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(Event.new(:assistant_stream_started, "s1", %{}))
      |> Reducer.apply_event(
        Event.new(
          :tool_started,
          "s1",
          ToolEvent.started(id: "tool-1", name: "eval")
        )
      )

    assert [_, %AssistantMessage{loader_label: "Working"}] =
             ViewModel.from_state(state).body
  end

  test "uses explicit working messages for the loader" do
    state =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(Event.new(:assistant_stream_started, "s1", %{}))
      |> Reducer.apply_event(Event.new(:working_message_updated, "s1", %{message: "Indexing"}))

    assert [%AssistantMessage{loader_label: "Indexing"}] =
             ViewModel.from_state(state).body
  end

  test "keeps tool calls between surrounding assistant text blocks" do
    state =
      State.new(session_id: "s1", cwd: "/tmp", model: "openai_codex:gpt-5.5")
      |> Reducer.apply_event(Event.new(:assistant_stream_started, "s1", %{}))
      |> Reducer.apply_event(Event.new(:assistant_delta, "s1", %{text: "Before."}))
      |> Reducer.apply_event(
        Event.new(
          :tool_started,
          "s1",
          ToolEvent.started(id: "tool-1", name: "eval")
        )
      )
      |> Reducer.apply_event(Event.new(:assistant_delta, "s1", %{text: "After."}))

    assert [
             %AssistantMessage{text: "Before."},
             %ToolCall{id: "tool-1"},
             %AssistantMessage{text: "After."}
           ] = ViewModel.from_state(state).body
  end
end
