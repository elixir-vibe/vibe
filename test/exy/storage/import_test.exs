defmodule Exy.Storage.ImportTest do
  use ExUnit.Case, async: false

  setup do
    Exy.Session.Store.clear()
    :ok
  end

  test "imports Pi JSONL sessions into SQLite UI events" do
    dir = Path.join(System.tmp_dir!(), "exy-pi-import-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    file = Path.join(dir, "session.jsonl")

    entries = [
      %{
        type: "session",
        version: 1,
        id: "pi-session",
        timestamp: "2026-01-01T00:00:00.000Z",
        cwd: dir
      },
      %{
        type: "message",
        id: "1",
        parentId: nil,
        timestamp: "2026-01-01T00:00:01.000Z",
        message: %{role: "user", content: "hello"}
      },
      %{
        type: "message",
        id: "2",
        parentId: "1",
        timestamp: "2026-01-01T00:00:02.000Z",
        message: %{role: "assistant", content: [%{type: "text", text: "hi"}]}
      },
      %{
        type: "model_change",
        id: "3",
        timestamp: "2026-01-01T00:00:03.000Z",
        provider: "openai",
        modelId: "gpt-4o"
      }
    ]

    File.write!(file, Enum.map_join(entries, "\n", &Jason.encode!/1) <> "\n")

    assert {:ok, %{session_id: "pi-session", events: 3}} = Exy.Storage.Import.pi_path(file)

    assert [
             {1, %{type: :user_message_added, data: %{text: "hello"}}},
             {2, %{type: :assistant_message_added, data: %{text: "hi"}}},
             {3, %{type: :model_selected, data: %{model: "openai:gpt-4o"}}}
           ] = Exy.Session.Store.ui_events("pi-session")

    assert [%{id: "pi-session", message_count: 2, first_message: "hello", cwd: ^dir}] =
             Exy.Session.Store.list()
  after
    File.rm_rf(Path.join(System.tmp_dir!(), "exy-pi-import-*"))
  end
end
