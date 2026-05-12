defmodule Vibe.Session.RegistryTest do
  use ExUnit.Case, async: true

  alias Vibe.Session

  test "session self-registers in Registry during init" do
    id = "registry-self-#{System.unique_integer([:positive])}"
    {:ok, session} = Session.start_link(session_id: id, persist?: false)

    assert [{^session, _}] = Registry.lookup(Vibe.Registry, {:session, id})
    GenServer.stop(session)
  end

  test "session does not double-register when started with via name" do
    id = "registry-via-#{System.unique_integer([:positive])}"
    {:ok, session} = Session.start(session_id: id, persist?: false)

    assert [{^session, _}] = Registry.lookup(Vibe.Registry, {:session, id})
    GenServer.stop(session)
  end

  test "lookup finds self-registered sessions" do
    id = "registry-lookup-#{System.unique_integer([:positive])}"
    {:ok, session} = Session.start_link(session_id: id, persist?: false)

    assert {:ok, ^session} = Session.lookup(id)
    GenServer.stop(session)
  end

  test "background_session command emits session_backgrounded event" do
    id = "bg-event-#{System.unique_integer([:positive])}"
    {:ok, session} = Session.start_link(session_id: id, persist?: false)
    :ok = Session.attach(session, self()) |> elem(0) && :ok

    Session.dispatch(session, {:background_session, %{}})

    assert_receive {Session, :event, %{type: :session_backgrounded}}, 500
    GenServer.stop(session)
  end
end
