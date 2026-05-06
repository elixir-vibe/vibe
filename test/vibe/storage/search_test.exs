defmodule Vibe.Storage.SearchTest do
  use ExUnit.Case, async: false

  alias Vibe.UI.Event

  setup do
    Vibe.Session.Store.clear()
    :ok
  end

  test "searches session messages through SQLite FTS" do
    session_id = "fts-session"

    :ok =
      Event.new(:user_message_added, session_id, %{text: "Need SQLite full text search"},
        at: ~U[2026-01-01 00:00:00Z]
      )
      |> Vibe.Session.Store.append_ui_event(1)

    assert [result] = Vibe.Session.search("full text", session_id: session_id)
    assert result.source == :session
    assert result.owner_id == session_id
    assert result.text == "Need SQLite full text search"
    assert result.metadata.seq == 1
  end

  test "filters session search by cwd and excludes imported tools by default" do
    Vibe.Session.Store.ensure_session("project-a", ~U[2026-01-01 00:00:00Z],
      cwd: "/tmp/project-a"
    )

    Vibe.Session.Store.ensure_session("project-b", ~U[2026-01-01 00:00:00Z],
      cwd: "/tmp/project-b"
    )

    :ok =
      Vibe.Session.Store.append_ui_events([
        {1,
         Event.new(:assistant_message_added, "project-a", %{text: "needle conversation"},
           at: ~U[2026-01-01 00:00:01Z]
         )},
        {1,
         Event.new(:assistant_message_added, "project-b", %{text: "needle conversation"},
           at: ~U[2026-01-01 00:00:02Z]
         )},
        {2,
         Event.new(
           :assistant_message_added,
           "project-b",
           %{text: "needle tool dump", import_role: "tool"},
           at: ~U[2026-01-01 00:00:03Z]
         )}
      ])

    assert [%{owner_id: "project-a"}] = Vibe.Session.search("needle", cwd: "project-a")
    assert [] = Vibe.Session.search("needle", cwd: "project-a", exclude_session_id: "project-a")
    assert [] = Vibe.Session.search("dump")
    assert [%{metadata: %{role: :tool}}] = Vibe.Session.search("dump", include_tools: true)
  end

  test "formats recalled history context from search results" do
    Vibe.Session.Store.ensure_session("recall-a", ~U[2026-01-01 00:00:00Z],
      cwd: "/tmp/recall-project"
    )

    :ok =
      Event.new(
        :assistant_message_added,
        "recall-a",
        %{text: "Use the blue Figma token for primary buttons"},
        at: ~U[2026-01-01 00:00:01Z]
      )
      |> Vibe.Session.Store.append_ui_event(1)

    block = Vibe.Context.recall("Figma token", cwd: "recall-project", limit: 1)

    assert block =~ "<recalled-history>"
    assert block =~ "Use the blue Figma token"
    assert block =~ "recall-project"
  end

  test "rebuilds FTS indexes from persisted data" do
    assert {:ok, memory} = Vibe.Memory.add(:global, "Run mix ci before commits")

    Vibe.Storage.FTS.clear()
    assert %{memories: 0, ui_events: 0} = Vibe.Storage.FTS.status()

    assert :ok = Vibe.Storage.FTS.rebuild()

    assert [%{id: id, text: "Run mix ci before commits"}] = Vibe.Memory.search("mix ci")
    assert id == memory.id
  end
end
