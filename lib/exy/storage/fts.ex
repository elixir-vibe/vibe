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

      fts_rows
      |> Enum.chunk_every(500)
      |> Enum.each(&Exy.Repo.insert_all(UIEventFTS, &1))
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

    Exy.Repo.insert_all(MemoryFTS, [
      %{
        memory_id: memory.id,
        scope_type: memory.scope_type,
        scope_id: memory.scope_id,
        inserted_at: DateTime.to_iso8601(memory.inserted_at),
        text: memory.text
      }
    ])

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

    UIEvent
    |> Exy.Repo.all()
    |> Enum.each(&index_ui_event/1)

    Memory
    |> Exy.Repo.all()
    |> Enum.each(&index_memory/1)

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
            role: Map.fetch!(@message_types, type),
            at: DateTime.to_iso8601(event.at),
            text: text
          }
        ]

      nil ->
        []
    end
  end

  defp ui_event_fts_row(_event), do: []

  defp text_from_data(%{"text" => text}) when is_binary(text), do: text
  defp text_from_data(%{text: text}) when is_binary(text), do: text
  defp text_from_data(_data), do: nil

  defp escape_token(token) do
    token
    |> String.replace(~s("), ~s(""))
    |> then(&~s("#{&1}"))
  end
end
