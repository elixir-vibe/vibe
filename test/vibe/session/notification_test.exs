defmodule Vibe.Session.NotificationTest do
  use ExUnit.Case, async: true

  alias Vibe.Session
  alias Vibe.UI.{Command, Event}

  test "notifications get ids and expire as transient UI state" do
    {:ok, session} = Session.start_link(persist?: false, session_id: "notification-expiry")

    :ok =
      Session.dispatch(
        session,
        Command.new(:notification_added, %{level: :error, text: "temporary error", ttl_ms: 50})
      )

    assert [%{id: id, text: "temporary error"}] = Session.state(session).notifications
    assert is_binary(id)

    # Wait for the timer to fire, then flush the GenServer mailbox with a sync call
    Process.sleep(80)
    assert Session.state(session).notifications == []
  end

  test "notifications are not replayed from durable session history" do
    {:ok, session} = Session.start_link(session_id: "notification-transient")

    :ok =
      Session.emit_event(
        session,
        Event.new(:notification_added, "notification-transient", %{text: "do not restore"})
      )

    assert [_notice] = Session.state(session).notifications
    GenServer.stop(session)

    {:ok, restored} = Session.start_link(session_id: "notification-transient", restoring?: true)
    assert Session.state(restored).notifications == []
  end
end
