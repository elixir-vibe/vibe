defmodule Exy.UI.ReducerTest do
  use ExUnit.Case, async: true

  test "reduces semantic chat and usage events" do
    state = Exy.UI.State.new(session_id: "ui-test", cwd: "/tmp", model: "openai_codex:gpt-5.5")

    events = [
      Exy.UI.Event.new(:user_message_added, "ui-test", %{text: "hello"}),
      Exy.UI.Event.new(:assistant_message_added, "ui-test", %{text: "hi"}),
      Exy.UI.Event.new(:usage_updated, "ui-test", %{
        input_tokens: 2,
        output_tokens: 3,
        total_tokens: 5
      })
    ]

    state = Exy.UI.Reducer.apply_events(state, events)

    assert Enum.map(state.messages, & &1.role) == [:user, :assistant]
    assert state.usage.total_tokens == 5
    assert state.status == :idle
    assert length(state.events) == 3
  end

  test "updates selected model and effort" do
    state = Exy.UI.State.new(session_id: "ui-test", model: "model-a", effort: :medium)

    state =
      state
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:model_selected, "ui-test", %{model: "model-b"})
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:effort_selected, "ui-test", %{effort: :high})
      )

    assert state.model == "model-b"
    assert state.effort == :high
  end

  test "previews token usage while assistant response streams" do
    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:user_message_added, "ui-test", %{text: "hello"})
      )
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_delta, "ui-test", %{text: "streaming text"})
      )

    assert state.usage.total_tokens == 0
    assert state.usage_preview.input_tokens == 2
    assert state.usage_preview.output_tokens == 4
    assert state.usage_preview.total_tokens == 6

    state =
      Exy.UI.Reducer.apply_event(
        state,
        Exy.UI.Event.new(:usage_updated, "ui-test", %{
          input_tokens: 10,
          output_tokens: 20,
          total_tokens: 30
        })
      )

    assert state.usage.total_tokens == 30
    assert state.usage_preview.total_tokens == 0
  end

  test "tracks overlays and tool state" do
    state = Exy.UI.State.new(session_id: "ui-test")

    state =
      state
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:overlay_opened, "ui-test", %{kind: :session_selector})
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "ui-test",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "eval")
        )
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_finished,
          "ui-test",
          Exy.UI.ToolEvent.finished(id: "tool-1", status: :ok)
        )
      )

    assert [%{kind: :session_selector}] = state.overlays
    assert state.pending_tools["tool-1"].name == "eval"
    assert state.pending_tools["tool-1"].status == :ok
    assert %{role: :tool, id: "tool-1", status: :ok} = List.last(state.messages)
    assert state.status == :idle
  end

  test "tool updates create a preparing tool card before execution starts" do
    state = Exy.UI.State.new(session_id: "s1")

    event =
      Exy.UI.Event.new(
        :tool_updated,
        "s1",
        Exy.UI.ToolEvent.preparing(id: "call-1", name: :eval, args: %{code: "IO."})
      )

    state = Exy.UI.Reducer.apply_event(state, event)

    assert [%{role: :tool, id: "call-1", status: :preparing, args: %{code: "IO."}}] =
             state.messages

    assert %{"call-1" => %{status: :preparing, args: %{code: "IO."}}} = state.pending_tools
  end

  test "tool start updates the preparing card instead of duplicating it" do
    state = Exy.UI.State.new(session_id: "s1")

    state =
      Exy.UI.Reducer.apply_event(
        state,
        Exy.UI.Event.new(
          :tool_updated,
          "s1",
          Exy.UI.ToolEvent.preparing(id: "call-1", name: :eval, args: %{code: "IO."})
        )
      )

    state =
      Exy.UI.Reducer.apply_event(
        state,
        Exy.UI.Event.new(
          :tool_started,
          "s1",
          Exy.UI.ToolEvent.started(id: "call-1", name: :eval, args: %{code: "IO.puts(:ok)"})
        )
      )

    assert [%{role: :tool, id: "call-1", status: :running, args: %{code: "IO.puts(:ok)"}}] =
             state.messages
  end

  test "tracks runtime alerts as active UI state and notifications" do
    alert =
      Exy.Runtime.Alert.from_alarm(:set, {:disk_almost_full, ~c"/tmp"}, [])
      |> Exy.Runtime.Alert.to_map()

    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:runtime_alert_set, "ui-test", %{alert: alert})
      )

    assert [%Exy.Runtime.Alert{type: :disk_almost_full}] = Map.values(state.runtime_alerts)
    assert [%Exy.UI.Notification{level: :error, text: text}] = state.notifications
    assert text =~ "Disk almost full"

    clear = Exy.Runtime.Alert.from_alarm(:clear, {:disk_almost_full, ~c"/tmp"}, [])

    state =
      Exy.UI.Reducer.apply_event(
        state,
        Exy.UI.Event.new(:runtime_alert_clear, "ui-test", %{
          alert: Exy.Runtime.Alert.to_map(clear)
        })
      )

    assert state.runtime_alerts == %{}
    assert List.last(state.notifications).level == :info
  end

  test "turns subagent lifecycle events into transcript blocks and notifications" do
    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:subagent_started, "ui-test", %{
          id: "sg-1",
          role: :scout,
          task: "inspect docs",
          child_session_id: "child-1"
        })
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:subagent_finished, "ui-test", %{
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

    assert Enum.any?(state.notifications, &String.contains?(&1.text, "exy a child-1"))
  end

  test "keeps session working between ReAct tool calls while stream is open" do
    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:user_message_added, "ui-test", %{text: "work"})
      )
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "ui-test",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "eval", args: %{code: "1 + 1"})
        )
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_finished,
          "ui-test",
          Exy.UI.ToolEvent.finished(id: "tool-1", name: "eval", output: {:ok, "2"})
        )
      )

    assert state.status == :working
    assert state.streaming_message

    state =
      Exy.UI.Reducer.apply_event(
        state,
        Exy.UI.Event.new(:assistant_stream_finished, "ui-test", %{})
      )

    assert state.status == :idle
  end

  test "stream finish reconciles final response text" do
    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_delta, "ui-test", %{text: "Reviewed../ `actsprogram_f`"})
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_stream_finished, "ui-test", %{
          text: "Reviewed `../program_facts`"
        })
      )

    assert [%{role: :assistant, text: "Reviewed `../program_facts`"}] = state.messages
    assert is_nil(state.streaming_message)
    assert state.status == :idle
  end

  test "stream finish appends final response when no delta created an assistant segment" do
    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "ui-test",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "eval")
        )
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_finished,
          "ui-test",
          Exy.UI.ToolEvent.finished(id: "tool-1", name: "eval", output: "ok")
        )
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_stream_finished, "ui-test", %{text: "Done"})
      )

    assert [%{role: :tool, id: "tool-1"}, %{role: :assistant, text: "Done"}] = state.messages
  end

  test "keeps assistant text and tool calls in chronological order" do
    state =
      Exy.UI.State.new(session_id: "ui-test")
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_started, "ui-test", %{}))
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_delta, "ui-test", %{text: "Before."})
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_started,
          "ui-test",
          Exy.UI.ToolEvent.started(id: "tool-1", name: "eval", args: %{code: "1 + 1"})
        )
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(
          :tool_finished,
          "ui-test",
          Exy.UI.ToolEvent.finished(id: "tool-1", name: "eval", output: {:ok, "2"})
        )
      )
      |> Exy.UI.Reducer.apply_event(
        Exy.UI.Event.new(:assistant_delta, "ui-test", %{text: "After."})
      )
      |> Exy.UI.Reducer.apply_event(Exy.UI.Event.new(:assistant_stream_finished, "ui-test", %{}))

    assert [
             %{role: :assistant, text: "Before."},
             %{role: :tool, id: "tool-1", output: "2"},
             %{role: :assistant, text: "After."}
           ] = state.messages
  end
end
