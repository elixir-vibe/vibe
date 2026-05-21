defmodule Vibe.UI.ReducerTest do
  use ExUnit.Case, async: true

  test "reduces semantic chat and usage events" do
    state = Vibe.UI.State.new(session_id: "ui-test", cwd: "/tmp", model: "openai_codex:gpt-5.5")

    events = [
      Vibe.UI.Event.new(:user_message_added, "ui-test", %{text: "hello"}),
      Vibe.UI.Event.new(:assistant_message_added, "ui-test", %{text: "hi"}),
      Vibe.UI.Event.new(:usage_updated, "ui-test", %{
        input_tokens: 2,
        output_tokens: 3,
        total_tokens: 5
      })
    ]

    state = Vibe.UI.Reducer.apply_events(state, events)

    assert Enum.map(state.messages, & &1.role) == [:user, :assistant]
    assert state.usage.total_tokens == 5
    assert state.status == :idle
    assert length(state.events) == 3
  end

  test "updates selected model and effort" do
    state = Vibe.UI.State.new(session_id: "ui-test", model: "model-a", effort: :medium)

    state =
      state
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:model_selected, "ui-test", %{model: "model-b"})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:effort_selected, "ui-test", %{effort: :high})
      )

    assert state.model == "model-b"
    assert state.effort == :high
    assert Enum.map(state.messages, & &1.role) == [:system, :system]
    assert Enum.map(state.messages, & &1.text) == ["Model: model-b", "Effort: high"]
  end

  test "coalesces consecutive model history markers semantically" do
    state =
      Vibe.UI.State.new(session_id: "ui-test", model: "model-a")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:model_selected, "ui-test", %{model: "model-b"})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:model_selected, "ui-test", %{model: "model-c"})
      )

    assert state.model == "model-c"

    assert Enum.map(state.messages, &Map.take(&1, [:role, :marker, :text])) == [
             %{role: :system, marker: :model_selected, text: "Model: model-c"}
           ]
  end

  test "keeps earlier model markers once conversation continues" do
    state =
      Vibe.UI.State.new(session_id: "ui-test", model: "model-a")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:model_selected, "ui-test", %{model: "model-b"})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:user_message_added, "ui-test", %{text: "hello"})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:model_selected, "ui-test", %{model: "model-c"})
      )

    assert Enum.map(state.messages, & &1.text) == ["Model: model-b", "hello", "Model: model-c"]
  end

  test "previews token usage while assistant response streams" do
    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:user_message_added, "ui-test", %{text: "hello"})
      )
      |> Vibe.UI.Reducer.apply_event(Vibe.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_delta, "ui-test", %{text: "streaming text"})
      )

    assert state.usage.total_tokens == 0
    assert state.usage_preview.input_tokens == 2
    assert state.usage_preview.output_tokens == 4
    assert state.usage_preview.total_tokens == 6

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(:usage_updated, "ui-test", %{
          input_tokens: 10,
          output_tokens: 20,
          total_tokens: 30
        })
      )

    assert state.usage.total_tokens == 30
    assert state.usage_preview.total_tokens == 0
  end

  test "tracks overlays and tool state" do
    state = Vibe.UI.State.new(session_id: "ui-test")

    state =
      state
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:overlay_opened, "ui-test", %{kind: :session_selector})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_started,
          "ui-test",
          Vibe.UI.ToolEvent.started(id: "tool-1", name: "eval")
        )
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_finished,
          "ui-test",
          Vibe.UI.ToolEvent.finished(id: "tool-1", status: :ok)
        )
      )

    assert [%{kind: :session_selector}] = state.overlays
    assert state.pending_tools["tool-1"].name == "eval"
    assert state.pending_tools["tool-1"].status == :ok
    assert %{role: :tool, id: "tool-1", status: :ok} = last_item(state.messages)
    assert state.status == :idle
  end

  test "tool updates create a preparing tool card before execution starts" do
    state = Vibe.UI.State.new(session_id: "s1")

    event =
      Vibe.UI.Event.new(
        :tool_updated,
        "s1",
        Vibe.UI.ToolEvent.preparing(id: "call-1", name: :eval, args: %{code: "IO."})
      )

    state = Vibe.UI.Reducer.apply_event(state, event)

    assert [%{role: :tool, id: "call-1", status: :preparing, args: %{code: "IO."}}] =
             state.messages

    assert %{"call-1" => %{status: :preparing, args: %{code: "IO."}}} = state.pending_tools
  end

  test "tool start updates the preparing card instead of duplicating it" do
    state = Vibe.UI.State.new(session_id: "s1")

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(
          :tool_updated,
          "s1",
          Vibe.UI.ToolEvent.preparing(id: "call-1", name: :eval, args: %{code: "IO."})
        )
      )

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(
          :tool_started,
          "s1",
          Vibe.UI.ToolEvent.started(id: "call-1", name: :eval, args: %{code: "IO.puts(:ok)"})
        )
      )

    assert [%{role: :tool, id: "call-1", status: :running, args: %{code: "IO.puts(:ok)"}}] =
             state.messages
  end

  test "tool finish without args preserves started args" do
    state = Vibe.UI.State.new(session_id: "s1")

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(
          :tool_started,
          "s1",
          Vibe.UI.ToolEvent.started(id: "call-1", name: :eval, args: %{code: "IO.puts(:ok)"})
        )
      )

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(
          :tool_finished,
          "s1",
          Vibe.UI.ToolEvent.finished(id: "call-1", name: :eval, output: "ok")
        )
      )

    assert [%{role: :tool, id: "call-1", status: :ok, args: %{code: "IO.puts(:ok)"}}] =
             state.messages
  end

  test "tracks runtime alerts as active UI state and notifications" do
    alert =
      Vibe.SystemAlarms.Alert.from_alarm(:set, {:disk_almost_full, ~c"/tmp"}, [])
      |> Vibe.SystemAlarms.Alert.to_map()

    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:runtime_alert_set, "ui-test", %{alert: alert})
      )

    assert [%Vibe.SystemAlarms.Alert{type: :disk_almost_full}] = Map.values(state.runtime_alerts)
    assert [%Vibe.UI.Notification{level: :error, text: text}] = state.notifications
    assert text =~ "Disk almost full"

    clear = Vibe.SystemAlarms.Alert.from_alarm(:clear, {:disk_almost_full, ~c"/tmp"}, [])

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(:runtime_alert_clear, "ui-test", %{
          alert: Vibe.SystemAlarms.Alert.to_map(clear)
        })
      )

    assert state.runtime_alerts == %{}
    assert last_item(state.notifications).level == :info
  end

  test "turns subagent lifecycle events into transcript blocks and notifications" do
    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:subagent_started, "ui-test", %{
          id: "sg-1",
          role: :scout,
          task: "inspect docs",
          child_session_id: "child-1"
        })
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:subagent_finished, "ui-test", %{
          id: "sg-1",
          role: :scout,
          status: :ok,
          task: "inspect docs",
          child_session_id: "child-1"
        })
      )

    assert [
             %{role: :subagent, role_name: :scout, lifecycle: :started},
             %{role: :subagent, role_name: :scout, lifecycle: :finished, status: :ok}
           ] = state.messages

    assert Enum.any?(state.notifications, &String.contains?(&1.text, "vibe a child-1"))
  end

  test "keeps session working between ReAct tool calls while stream is open" do
    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:user_message_added, "ui-test", %{text: "work"})
      )
      |> Vibe.UI.Reducer.apply_event(Vibe.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_started,
          "ui-test",
          Vibe.UI.ToolEvent.started(id: "tool-1", name: "eval", args: %{code: "1 + 1"})
        )
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_finished,
          "ui-test",
          Vibe.UI.ToolEvent.finished(id: "tool-1", name: "eval", output: {:ok, "2"})
        )
      )

    assert state.status == :working
    assert state.streaming_message

    state =
      Vibe.UI.Reducer.apply_event(
        state,
        Vibe.UI.Event.new(:assistant_stream_finished, "ui-test", %{})
      )

    assert state.status == :idle
  end

  defp last_item([item]), do: item
  defp last_item([_item | items]), do: last_item(items)

  test "stream finish reconciles final response text" do
    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(Vibe.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_delta, "ui-test", %{text: "Reviewed../ `actsprogram_f`"})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_stream_finished, "ui-test", %{
          text: "Reviewed `../program_facts`"
        })
      )

    assert [%{role: :assistant, text: "Reviewed `../program_facts`"}] = state.messages
    assert is_nil(state.streaming_message)
    assert state.status == :idle
  end

  test "stream finish appends final response when no delta created an assistant segment" do
    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(Vibe.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_started,
          "ui-test",
          Vibe.UI.ToolEvent.started(id: "tool-1", name: "eval")
        )
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_finished,
          "ui-test",
          Vibe.UI.ToolEvent.finished(id: "tool-1", name: "eval", output: "ok")
        )
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_stream_finished, "ui-test", %{text: "Done"})
      )

    assert [%{role: :tool, id: "tool-1"}, %{role: :assistant, text: "Done"}] = state.messages
  end

  test "keeps assistant text and tool calls in chronological order" do
    state =
      Vibe.UI.State.new(session_id: "ui-test")
      |> Vibe.UI.Reducer.apply_event(Vibe.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_delta, "ui-test", %{text: "Before."})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_started,
          "ui-test",
          Vibe.UI.ToolEvent.started(id: "tool-1", name: "eval", args: %{code: "1 + 1"})
        )
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(
          :tool_finished,
          "ui-test",
          Vibe.UI.ToolEvent.finished(id: "tool-1", name: "eval", output: {:ok, "2"})
        )
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_delta, "ui-test", %{text: "After."})
      )
      |> Vibe.UI.Reducer.apply_event(
        Vibe.UI.Event.new(:assistant_stream_finished, "ui-test", %{})
      )

    assert [
             %{role: :assistant, text: "Before."},
             %{role: :tool, id: "tool-1", output: "2"},
             %{role: :assistant, text: "After."}
           ] = state.messages
  end
end
