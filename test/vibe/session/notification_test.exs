defmodule Vibe.Session.NotificationTest do
  use ExUnit.Case, async: true

  alias Vibe.Session
  alias Vibe.UI.{Command, Event}

  test "notifications get ids and expire as transient UI state" do
    {:ok, session} = Session.start_link(persist?: false, session_id: "notification-expiry")

    :ok =
      Session.dispatch(
        session,
        Command.new(:notification_added, %{level: :error, text: "temporary error", ttl_ms: 20})
      )

    assert [%{id: id, text: "temporary error"}] = Session.state(session).notifications
    assert is_binary(id)

    assert eventually(fn -> Session.state(session).notifications == [] end)
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

  defp eventually(fun, deadline \\ System.monotonic_time(:millisecond) + 500) do
    cond do
      fun.() ->
        true

      System.monotonic_time(:millisecond) < deadline ->
        Process.sleep(10)
        eventually(fun, deadline)

      true ->
        false
    end
  end
end
