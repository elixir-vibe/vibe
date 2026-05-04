defmodule Exy.Storage.FTS do
  @moduledoc "SQLite FTS5 full-text search query helpers."
  import Ecto.Query

  alias Exy.Repo
  alias Exy.Storage.Schema.{Memory, MemoryFTS, UIEvent, UIEventFTS}

  @rebuild_batch_size 2_000
  @insert_chunk_size 1_000

  @message_types %{
    "user_message_added" => "user",
    "assistant_message_added" => "assistant"
  }

  @spec index_ui_event(struct()) :: :ok
  def index_ui_event(%UIEvent{} = event), do: index_ui_event_rows([event])

  @spec index_ui_event_rows([map() | struct()]) :: :ok
  def index_ui_event_rows(rows) when is_list(rows) do
    rows
    |> Enum.flat_map(&ui_event_fts_row/1)
    |> insert_ui_event_fts_rows()
  end

  @spec remove_ui_event(String.t()) :: :ok
  def remove_ui_event(event_id) when is_binary(event_id) do
    Exy.Repo.delete_all(from(row in UIEventFTS, where: row.event_id == ^event_id))
    :ok
  end

  @spec index_memory(struct()) :: :ok
  def index_memory(%Memory{} = memory) do
    Exy.Repo.delete_all(from(row in MemoryFTS, where: row.memory_id == ^memory.id))

    Exy.Repo.insert_all(MemoryFTS, [memory_fts_row(memory)])

    :ok
  end

  @spec remove_memory(String.t()) :: :ok
  def remove_memory(memory_id) when is_binary(memory_id) do
    Exy.Repo.delete_all(from(row in MemoryFTS, where: row.memory_id == ^memory_id))
    :ok
  end

  @spec clear() :: :ok
  def clear do
    Exy.Repo.delete_all(UIEventFTS)
    Exy.Repo.delete_all(MemoryFTS)
    :ok
  end

  @spec rebuild(keyword()) :: :ok
  def rebuild(opts \\ []) do
    clear()

    progress(opts, %{
      phase: :fts_rebuild_start,
      ui_events: Repo.aggregate(UIEvent, :count),
      memories: Repo.aggregate(Memory, :count)
    })

    rebuild_ui_events(0, 0, opts)
    rebuild_memories("", 0, opts)

    progress(opts, %{
      phase: :fts_rebuild_done,
      ui_events: Repo.aggregate(UIEventFTS, :count),
      memories: Repo.aggregate(MemoryFTS, :count)
    })

    :ok
  end

  defp rebuild_ui_events(last_id, indexed, opts) do
    rows =
      UIEvent
      |> where([event], event.id > ^last_id)
      |> order_by([event], event.id)
      |> limit(@rebuild_batch_size)
      |> Exy.Repo.all()

    case rows do
      [] ->
        :ok

      rows ->
        rows
        |> Enum.flat_map(&ui_event_fts_row/1)
        |> insert_ui_event_fts_rows()

        indexed = indexed + length(rows)
        progress(opts, %{phase: :fts_ui_events, indexed: indexed})
        rows |> List.last() |> Map.fetch!(:id) |> rebuild_ui_events(indexed, opts)
    end
  end

  defp rebuild_memories(last_id, indexed, opts) do
    rows =
      Memory
      |> where([memory], memory.id > ^last_id)
      |> order_by([memory], memory.id)
      |> limit(@rebuild_batch_size)
      |> Exy.Repo.all()

    case rows do
      [] ->
        :ok

      rows ->
        rows
        |> Enum.map(&memory_fts_row/1)
        |> insert_memory_fts_rows()

        indexed = indexed + length(rows)
        progress(opts, %{phase: :fts_memories, indexed: indexed})
        rows |> List.last() |> Map.fetch!(:id) |> rebuild_memories(indexed, opts)
    end
  end

  defp insert_ui_event_fts_rows([]), do: :ok

  defp insert_ui_event_fts_rows(rows) do
    rows
    |> Enum.chunk_every(@insert_chunk_size)
    |> Enum.each(&Exy.Repo.insert_all(UIEventFTS, &1))
  end

  defp insert_memory_fts_rows([]), do: :ok

  defp insert_memory_fts_rows(rows) do
    rows
    |> Enum.chunk_every(@insert_chunk_size)
    |> Enum.each(&Exy.Repo.insert_all(MemoryFTS, &1))
  end

  defp progress(opts, event) do
    case Keyword.get(opts, :progress) do
      fun when is_function(fun, 1) -> fun.(event)
      _progress -> :ok
    end
  end

  defp memory_fts_row(%Memory{} = memory) do
    %{
      memory_id: memory.id,
      scope_type: memory.scope_type,
      scope_id: memory.scope_id,
      inserted_at: DateTime.to_iso8601(memory.inserted_at),
      text: memory.text
    }
  end

  @spec optimize() :: :ok
  def optimize do
    Ecto.Adapters.SQL.query!(
      Exy.Repo,
      "INSERT INTO ui_events_fts(ui_events_fts) VALUES('optimize')",
      []
    )

    Ecto.Adapters.SQL.query!(
      Exy.Repo,
      "INSERT INTO memories_fts(memories_fts) VALUES('optimize')",
      []
    )

    :ok
  end

  @spec status() :: map()
  def status do
    %{
      ui_events: Repo.aggregate(UIEventFTS, :count),
      memories: Repo.aggregate(MemoryFTS, :count)
    }
  end

  @spec plain_query(String.t()) :: String.t()
  def plain_query(query) when is_binary(query) do
    query
    |> String.downcase()
    |> String.split(~r/[^\p{L}\p{N}_]+/u, trim: true)
    |> Enum.map(&escape_token/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp ui_event_fts_row(%UIEvent{} = event) do
    event
    |> Map.from_struct()
    |> ui_event_fts_row()
  end

  defp ui_event_fts_row(%{type: type, data: data} = event)
       when is_map_key(@message_types, type) do
    case text_from_data(data) do
      text when is_binary(text) ->
        [
          %{
            session_id: event.session_id,
            event_id: event.event_id,
            seq: event.seq,
            role: event_role(type, data),
            at: DateTime.to_iso8601(event.at),
            text: text
          }
        ]

      nil ->
        []
    end
  end

  defp ui_event_fts_row(_event), do: []

  defp event_role("assistant_message_added", %{import_role: "tool"}), do: "tool"
  defp event_role("assistant_message_added", %{"import_role" => "tool"}), do: "tool"
  defp event_role(type, _data), do: Map.fetch!(@message_types, type)

  defp text_from_data(%{"text" => text}) when is_binary(text), do: text
  defp text_from_data(%{text: text}) when is_binary(text), do: text
  defp text_from_data(_data), do: nil

  defp escape_token(token) do
    token
    |> String.replace(~s("), ~s(""))
    |> then(&~s("#{&1}"))
  end
end
