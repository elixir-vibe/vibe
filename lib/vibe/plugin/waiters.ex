defmodule Vibe.Plugin.Waiters do
  @moduledoc "ETS-backed session waiter registry for interactive plugins."

  @spec ensure_table!(atom()) :: :ok
  def ensure_table!(table) when is_atom(table) do
    unless table?(table), do: :ets.new(table, [:named_table, :public, :set])
    :ok
  rescue
    ArgumentError -> :ok
  end

  @spec register(atom(), String.t(), pid()) :: :ok
  def register(table, session_id, pid)
      when is_atom(table) and is_binary(session_id) and is_pid(pid) do
    ensure_table!(table)
    :ets.insert(table, {session_id, pid})
    :ok
  end

  @spec unregister(atom(), String.t()) :: :ok
  def unregister(table, session_id) when is_atom(table) and is_binary(session_id) do
    if table?(table), do: :ets.delete(table, session_id)
    :ok
  end

  @spec pop(atom(), String.t()) :: {:ok, pid()} | :error
  def pop(table, session_id) when is_atom(table) and is_binary(session_id) do
    if table?(table) do
      case :ets.lookup(table, session_id) do
        [{^session_id, pid}] ->
          :ets.delete(table, session_id)
          {:ok, pid}

        [] ->
          :error
      end
    else
      :error
    end
  end

  @spec table?(atom()) :: boolean()
  def table?(table) when is_atom(table), do: :ets.info(table) != :undefined
end
