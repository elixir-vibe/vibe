defmodule Vibe.Session.ListingTest do
  use ExUnit.Case, async: false

  setup do
    Vibe.Session.Store.clear()
    :ok
  end

  test "omits empty stored and live sessions from recent useful listing" do
    {:ok, empty_live} = Vibe.Session.start_link(session_id: "listing-empty-live")
    Vibe.Session.Store.ensure_session("listing-empty-stored", DateTime.utc_now())

    Vibe.Session.Store.append_ui_event(
      Vibe.Event.new(:user_message_added, "listing-useful", %{text: "keep me"}),
      1
    )

    ids = Vibe.Session.list() |> Enum.map(& &1.id)

    assert "listing-useful" in ids
    refute "listing-empty-live" in ids
    refute "listing-empty-stored" in ids

    GenServer.stop(empty_live)
  end

  test "stored SQLite sessions can be looked up without legacy JSON files" do
    Vibe.Session.Store.append_ui_event(
      Vibe.Event.new(:user_message_added, "listing-restored", %{text: "restore me"}),
      1
    )

    assert {:ok, session} = Vibe.Session.lookup("listing-restored")
    assert [%{text: "restore me", role: :user}] = Vibe.Session.state(session).messages
  end
end
