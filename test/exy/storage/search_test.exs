defmodule Exy.Storage.SearchTest do
  use ExUnit.Case, async: false

  alias Exy.UI.Event

  setup do
    Exy.Session.Store.clear()
    :ok
  end

  test "searches session messages through SQLite FTS" do
    session_id = "fts-session"

    :ok =
      Event.new(:user_message_added, session_id, %{text: "Need SQLite full text search"},
        at: ~U[2026-01-01 00:00:00Z]
      )
      |> Exy.Session.Store.append_ui_event(1)

    assert [result] = Exy.Session.search("full text", session_id: session_id)
    assert result.source == :session
    assert result.owner_id == session_id
    assert result.text == "Need SQLite full text search"
    assert result.metadata.seq == 1
  end

  test "rebuilds FTS indexes from persisted data" do
    assert {:ok, memory} = Exy.Memory.add(:global, "Run mix ci before commits")

    Exy.Storage.FTS.clear()
    assert %{memories: 0, ui_events: 0} = Exy.Storage.FTS.status()

    assert :ok = Exy.Storage.FTS.rebuild()

    assert [%{id: id, text: "Run mix ci before commits"}] = Exy.Memory.search("mix ci")
    assert id == memory.id
  end
end
