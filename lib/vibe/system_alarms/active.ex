defmodule Vibe.SystemAlarms.Active do
  @moduledoc false

  @key {__MODULE__, :alerts}

  @spec reset() :: :ok
  def reset do
    :persistent_term.put(@key, %{})
    :ok
  end

  @spec put(Vibe.SystemAlarms.Alert.t()) :: :ok
  def put(alert) do
    alerts = Map.put(alerts(), alert.id, alert)
    :persistent_term.put(@key, alerts)
    :ok
  end

  @spec delete(Vibe.SystemAlarms.Alert.t()) :: :ok
  def delete(alert) do
    alerts = Map.delete(alerts(), alert.id)
    :persistent_term.put(@key, alerts)
    :ok
  end

  @spec active() :: [Vibe.SystemAlarms.Alert.t()]
  def active do
    @key
    |> :persistent_term.get(%{})
    |> Map.values()
    |> Enum.sort_by(& &1.id)
  end

  @spec map() :: %{String.t() => Vibe.SystemAlarms.Alert.t()}
  def map, do: alerts()

  defp alerts, do: :persistent_term.get(@key, %{})
end
