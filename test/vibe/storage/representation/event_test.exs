defmodule Vibe.Storage.Representation.EventTest do
  use ExUnit.Case, async: true

  alias Vibe.Storage.Representation.Event, as: EventRepresentation
  alias Vibe.SystemAlarms.Alert
  alias Vibe.Event

  test "encodes and decodes tool events through storage representation" do
    tool = Vibe.Tool.Event.started(id: "tool-1", name: :eval, args: %{code: "1 + 1"})

    event =
      Event.new(:tool_started, "session-1", Vibe.Event.Tool.started(tool),
        at: ~U[2026-05-20 12:00:01Z]
      )

    encoded = EventRepresentation.encode(event, 6)

    assert {:ok, {6, decoded}} = EventRepresentation.decode_map(encoded)
    assert %Event{data: %Vibe.Event.Tool.Started{event: ^tool}} = decoded
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

    event =
      Event.new(:goal_set, "session-1", Vibe.Event.Goal.set(goal), at: ~U[2026-05-20 12:00:01Z])

    encoded = EventRepresentation.encode(event, 7)

    assert {:ok, {7, decoded}} = EventRepresentation.decode_map(encoded)
    assert %Event{data: %Vibe.Event.Goal.Set{goal: ^goal}} = decoded
  end

  test "encodes and decodes selector opened events through storage representation" do
    selector = %Vibe.UI.Selector{
      kind: :model_selector,
      title: "Model",
      items: ["a", "b"],
      selected: 0,
      limit: 8
    }

    event =
      Event.new(:selector_opened, "session-1", Vibe.Event.Selector.opened(selector),
        at: ~U[2026-05-20 12:00:01Z]
      )

    encoded = EventRepresentation.encode(event, 9)

    assert {:ok, {9, decoded}} = EventRepresentation.decode_map(encoded)

    state =
      Vibe.UI.State.new(session_id: "session-1")
      |> Vibe.UI.Reducer.apply_event(decoded)

    assert state.selector.kind == :model_selector
    assert state.selector.items == ["a", "b"]
  end

  test "encodes and decodes runtime alert events through storage representation" do
    alert =
      Alert.from_alarm(:set, {:disk_almost_full, ~c"/tmp"}, [], at: ~U[2026-05-20 12:00:00Z])

    event =
      Event.new(:runtime_alert_set, "session-1", Vibe.Event.RuntimeAlert.set(alert),
        at: ~U[2026-05-20 12:00:01Z]
      )

    encoded = EventRepresentation.encode(event, 8)

    assert {:ok, {8, decoded}} = EventRepresentation.decode_map(encoded)
    assert %Event{data: %Vibe.Event.RuntimeAlert.Set{alert: ^alert}} = decoded
  end
end
