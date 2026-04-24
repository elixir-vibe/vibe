defmodule Exy.Trajectory.Store do
  @moduledoc """
  In-memory trajectory store for the first Exy vertical slice.

  The API is intentionally persistence-friendly; swapping this for SQLite/Ecto
  later should not affect callers.
  """

  use GenServer

  alias Exy.Trajectory

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec append(atom(), map(), keyword()) :: Trajectory.t()
  def append(type, data \\ %{}, opts \\ []) do
    event = Trajectory.new(type, data, opts)
    GenServer.call(__MODULE__, {:append, event})
    event
  end

  @spec list(keyword()) :: [Trajectory.t()]
  def list(opts \\ []) do
    GenServer.call(__MODULE__, {:list, opts})
  end

  @spec clear() :: :ok
  def clear, do: GenServer.call(__MODULE__, :clear)

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  def handle_call({:append, event}, _from, events), do: {:reply, :ok, [event | events]}

  def handle_call({:list, opts}, _from, events) do
    limit = Keyword.get(opts, :limit, :infinity)
    session_id = Keyword.get(opts, :session_id)
    type = Keyword.get(opts, :type)

    result =
      events
      |> Enum.reverse()
      |> maybe_filter(session_id, &(&1.session_id == session_id))
      |> maybe_filter(type, &(&1.type == type))
      |> take(limit)

    {:reply, result, events}
  end

  def handle_call(:clear, _from, _events), do: {:reply, :ok, []}

  defp maybe_filter(events, nil, _fun), do: events
  defp maybe_filter(events, _value, fun), do: Enum.filter(events, fun)

  defp take(events, :infinity), do: events
  defp take(events, limit), do: Enum.take(events, limit)
end
