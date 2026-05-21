defmodule Vibe.Storage.Representation.SessionLogTest do
  use ExUnit.Case, async: true

  alias Vibe.Storage.Representation.SessionLog
  alias Vibe.SystemAlarms.Alert
  alias Vibe.Event

  test "encodes and decodes tool events through storage representation" do
    tool = Vibe.Tool.Event.started(id: "tool-1", name: :eval, args: %{code: "1 + 1"})
    event = Event.new(:tool_started, "session-1", tool, at: ~U[2026-05-20 12:00:01Z])

    encoded = SessionLog.encode_ui_event(event, 6)

    assert {:ok, {6, decoded}} = SessionLog.decode_ui_event_map(encoded)
    assert %Event{data: ^tool} = decoded
  end

  test "encodes and decodes goal events through storage representation" do
    goal = %Vibe.Goals.Goal{
      session_id: "session-1",
      goal_id: "goal-1",
      objective: "Ship it",
      status: :active,
      token_budget: nil,
      tokens_used: 0,
      time_used_seconds: 0,
      created_at: ~U[2026-05-20 12:00:00Z],
      updated_at: ~U[2026-05-20 12:00:00Z]
    }

    event = Event.new(:goal_set, "session-1", %{goal: goal}, at: ~U[2026-05-20 12:00:01Z])

    encoded = SessionLog.encode_ui_event(event, 7)

    assert {:ok, {7, decoded}} = SessionLog.decode_ui_event_map(encoded)
    assert %Event{data: %{goal: ^goal}} = decoded
  end

  test "encodes and decodes runtime alert events through storage representation" do
    alert =
      Alert.from_alarm(:set, {:disk_almost_full, ~c"/tmp"}, [], at: ~U[2026-05-20 12:00:00Z])

    event =
      Event.new(:runtime_alert_set, "session-1", %{alert: alert}, at: ~U[2026-05-20 12:00:01Z])

    encoded = SessionLog.encode_ui_event(event, 8)

    assert {:ok, {8, decoded}} = SessionLog.decode_ui_event_map(encoded)
    assert %Event{data: %{alert: ^alert}} = decoded
  end
end
