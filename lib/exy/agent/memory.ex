defmodule Exy.Agent.Memory do
  @moduledoc """
  Ephemeral runtime memory scoped by running agent/subagent id.
  """

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec put(String.t(), atom(), term()) :: :ok
  def put(agent_id, key, value) when is_binary(agent_id) and is_atom(key),
    do: GenServer.call(__MODULE__, {:put, agent_id, key, value})

  @spec get(String.t(), atom()) :: {:ok, term()} | :error
  def get(agent_id, key) when is_binary(agent_id) and is_atom(key),
    do: GenServer.call(__MODULE__, {:get, agent_id, key})

  @spec list(String.t()) :: map()
  def list(agent_id) when is_binary(agent_id), do: GenServer.call(__MODULE__, {:list, agent_id})

  @spec clear(String.t()) :: :ok
  def clear(agent_id) when is_binary(agent_id), do: GenServer.call(__MODULE__, {:clear, agent_id})

  @impl true
  def init(_opts), do: {:ok, %{}}

  @impl true
  def handle_call({:put, agent_id, key, value}, _from, state) do
    {:reply, :ok, update_in(state, [agent_id], &Map.put(&1 || %{}, key, value))}
  end

  def handle_call({:get, agent_id, key}, _from, state) do
    case get_in(state, [agent_id, key]) do
      nil -> {:reply, :error, state}
      value -> {:reply, {:ok, value}, state}
    end
  end

  def handle_call({:list, agent_id}, _from, state) do
    {:reply, Map.get(state, agent_id, %{}), state}
  end

  def handle_call({:clear, agent_id}, _from, state) do
    {:reply, :ok, Map.delete(state, agent_id)}
  end
end
