defmodule Exy.Storage.FTS do
  @moduledoc false

  import Ecto.Query

  alias Exy.Storage.Schema.{Memory, MemoryFTS, UIEvent, UIEventFTS}

  @message_types %{
    "user_message_added" => "user",
    "assistant_message_added" => "assistant"
  }

  @spec index_ui_event(struct()) :: :ok
  def index_ui_event(%UIEvent{} = event), do: index_ui_event_rows([event])

  @spec index_ui_event_rows([map() | struct()]) :: :ok
  def index_ui_event_rows(rows) when is_list(rows) do
    fts_rows = Enum.flat_map(rows, &ui_event_fts_row/1)
    event_ids = Enum.map(fts_rows, & &1.event_id)

    if event_ids != [] do
      Exy.Repo.delete_all(from(row in UIEventFTS, where: row.event_id in ^event_ids))
      insert_ui_event_fts_rows(fts_rows)
    end

    :ok
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

  @spec rebuild() :: :ok
  def rebuild do
    clear()
    rebuild_ui_events(0)
    rebuild_memories("")
    :ok
  end

  defp rebuild_ui_events(last_id) do
    rows =
      UIEvent
      |> where([event], event.id > ^last_id)
      |> order_by([event], event.id)
      |> limit(2_000)
      |> Exy.Repo.all()

    case rows do
      [] ->
        :ok

      rows ->
        rows
        |> Enum.flat_map(&ui_event_fts_row/1)
        |> insert_ui_event_fts_rows()

        rows |> List.last() |> Map.fetch!(:id) |> rebuild_ui_events()
    end
  end

  defp rebuild_memories(last_id) do
    rows =
      Memory
      |> where([memory], memory.id > ^last_id)
      |> order_by([memory], memory.id)
      |> limit(2_000)
      |> Exy.Repo.all()

    case rows do
      [] ->
        :ok

      rows ->
        rows
        |> Enum.map(&memory_fts_row/1)
        |> insert_memory_fts_rows()

        rows |> List.last() |> Map.fetch!(:id) |> rebuild_memories()
    end
  end

  defp insert_ui_event_fts_rows([]), do: :ok

  defp insert_ui_event_fts_rows(rows) do
    rows
    |> Enum.chunk_every(1_000)
    |> Enum.each(&Exy.Repo.insert_all(UIEventFTS, &1))
  end

  defp insert_memory_fts_rows([]), do: :ok

  defp insert_memory_fts_rows(rows) do
    rows
    |> Enum.chunk_every(1_000)
    |> Enum.each(&Exy.Repo.insert_all(MemoryFTS, &1))
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
      ui_events: Exy.Repo.aggregate(UIEventFTS, :count),
      memories: Exy.Repo.aggregate(MemoryFTS, :count)
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
