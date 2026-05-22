defmodule Vibe.Session.NotificationTest do
  use ExUnit.Case, async: true

  alias Vibe.Session
  alias Vibe.Event
  alias Vibe.UI.Command

  test "notifications get ids and expire as transient UI state" do
    session_id = "notification-expiry-#{System.unique_integer([:positive])}"
    {:ok, session} = Session.start_link(persist?: false, session_id: session_id)

    :ok =
      Session.dispatch(
        session,
        Command.new(:notification_added, %{level: :error, text: "temporary error", ttl_ms: 200})
      )

    assert [%{id: id, text: "temporary error"}] = Session.state(session).notifications
    assert is_binary(id)

    wait_until(fn -> Session.state(session).notifications == [] end)
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

  defp wait_for_notifications(session) do
    wait_until(fn ->
      case Session.state(session).notifications do
        [] -> false
        notifications -> notifications
      end
    end)
  end

  defp wait_until(fun, attempts \\ 50)
  defp wait_until(_fun, 0), do: flunk("condition was not met")

  defp wait_until(fun, attempts) do
    case fun.() do
      false ->
        Process.sleep(10)
        wait_until(fun, attempts - 1)

      value ->
        value
    end
  end
end
