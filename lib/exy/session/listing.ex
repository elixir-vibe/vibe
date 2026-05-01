defmodule Exy.Session.Listing do
  @moduledoc "Internal implementation module."
  @spec active_count() :: non_neg_integer()
  def active_count do
    Registry.select(Exy.Registry, [{{{:session, :"$1"}, :"$2", :"$3"}, [], [true]}])
    |> length()
  end

  @spec list() :: [map()]
  def list do
    live =
      Registry.select(Exy.Registry, [
        {{{:session, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}
      ])
      |> Enum.map(&live_info/1)

    stored = Exy.Session.Store.list() |> Enum.map(&Map.put(&1, :live?, false))
    live_ids = MapSet.new(Enum.map(live, & &1.id))

    (live ++ Enum.reject(stored, &MapSet.member?(live_ids, &1.id)))
    |> Enum.sort_by(&updated_at_sort_key/1, :desc)
  end

  @spec start_stored(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def start_stored(id) do
    if stored?(id),
      do: Exy.Session.start(session_id: id, restoring?: true),
      else: {:error, :not_found}
  end

  @spec via(String.t()) :: {:via, Registry, {Exy.Registry, {:session, String.t()}}}
  def via(id), do: {:via, Registry, {Exy.Registry, {:session, id}}}

  defp updated_at_sort_key(%{updated_at: %DateTime{} = updated_at}),
    do: DateTime.to_unix(updated_at, :microsecond)

  defp updated_at_sort_key(_session), do: 0

  defp live_info({id, pid}) do
    state = Exy.Session.state(pid)
    stored = Exy.Session.Store.info(id) || %{id: id}

    stored
    |> Map.merge(%{
      id: id,
      live?: true,
      status: state.status,
      model: state.model,
      message_count: length(state.messages),
      last_message_preview: state.messages |> List.last() |> Exy.Session.Preview.message(),
      usage: state.usage
    })
  end

  defp stored?(id) do
    File.exists?(Exy.Session.Store.path(id)) or File.exists?(Exy.Session.Store.ui_events_path(id))
  end
end
