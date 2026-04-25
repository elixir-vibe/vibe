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
      [] -> {:error, :not_found}
    end
  end

  @spec list() :: [map()]
  def list do
    live =
      Registry.select(Exy.Registry, [
        {{{:session, :"$1"}, :"$2", :"$3"}, [], [%{id: :"$1", live?: true}]}
      ])

    stored = Exy.Session.Store.list() |> Enum.map(&Map.put(&1, :live?, false))
    live_ids = MapSet.new(Enum.map(live, & &1.id))
    live ++ Enum.reject(stored, &MapSet.member?(live_ids, &1.id))
  end

  defp via(id), do: {:via, Registry, {Exy.Registry, {:session, id}}}
end
