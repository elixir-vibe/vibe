defmodule Exy.Sessions do
  @moduledoc false

  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    id = Keyword.get_lazy(opts, :session_id, &Exy.Session.Store.new_id/0)
    opts = Keyword.put(opts, :session_id, id)

    DynamicSupervisor.start_child(
      Exy.SessionSupervisor,
      %{
        id: {Exy.Session, id},
        start: {Exy.Session, :start_link, [Keyword.put(opts, :name, via(id))]},
        restart: :temporary
      }
    )
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def lookup(id) do
    case Registry.lookup(Exy.Registry, {:session, id}) do
      [{pid, _value}] -> {:ok, pid}
      [] -> start_stored(id)
    end
  end

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

  defp start_stored(id) do
    if stored?(id), do: start(session_id: id, restoring?: true), else: {:error, :not_found}
  end

  defp stored?(id) do
    File.exists?(Exy.Session.Store.path(id)) or File.exists?(Exy.Session.Store.ui_events_path(id))
  end

  defp via(id), do: {:via, Registry, {Exy.Registry, {:session, id}}}
end
