defmodule Vibe.Storage.Representation.TrajectoryTest do
  use ExUnit.Case, async: true

  alias Vibe.Event
  alias Vibe.Storage.Representation.Trajectory, as: TrajectoryRepresentation
  alias Vibe.Trajectory

  test "round-trips trajectory storage maps" do
    at = DateTime.utc_now()
    event = Trajectory.new(:user_message, %{prompt: "hello"}, session_id: "s1", at: at)

    encoded = TrajectoryRepresentation.encode(event)

    assert {:ok, %Trajectory{type: :user_message, session_id: "s1", data: %{prompt: "hello"}}} =
             TrajectoryRepresentation.decode_map(encoded)
  end

  test "projects persisted trajectory into semantic events" do
    at = DateTime.utc_now()

    trajectory =
      Trajectory.new(:assistant_message, %{result: "done"}, session_id: "s1", at: at)

    assert [
             {1,
              %Event{type: :assistant_message_added, session_id: "s1", data: %{result: "done"}}}
           ] =
             TrajectoryRepresentation.project_events([trajectory])
  end
end
