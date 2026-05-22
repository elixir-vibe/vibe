defmodule Vibe.Context.CompactorTest do
  use ExUnit.Case, async: true

  alias Vibe.Context.{Compactor, Serializer}
  alias Vibe.Trajectory

  defp trajectory(type, data) do
    %Trajectory{
      id: "evt-#{System.unique_integer([:positive])}",
      type: type,
      data: data,
      session_id: "test",
      at: DateTime.utc_now()
    }
  end

  test "find_cut_point splits at token boundary, not event count" do
    short = trajectory(:user_message, %{prompt: "hi"})
    long = trajectory(:assistant_message, %{result: String.duplicate("word ", 5000)})
    recent = trajectory(:user_message, %{prompt: "latest question"})

    events = [short, long, recent]

    {old, kept} = Compactor.find_cut_point_for_test(events, 100)
    assert old != []
    assert kept != []
    assert hd(kept).type in [:user_message, :assistant_message]
  end

  test "snap_to_boundary skips tool_result events" do
    events = [
      trajectory(:tool_result, %{result: "output"}),
      trajectory(:tool_call, %{name: :eval}),
      trajectory(:user_message, %{prompt: "hello"})
    ]

    snapped = Compactor.snap_to_boundary_for_test(events)
    assert hd(snapped).type == :user_message
  end

  test "event_tokens estimates from serialized size" do
    event = trajectory(:user_message, %{prompt: String.duplicate("hello ", 100)})
    tokens = Serializer.event_tokens(event)
    assert tokens > 0
    assert tokens < 1000
  end
end
