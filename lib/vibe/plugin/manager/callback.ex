defmodule Vibe.Plugin.Manager.Callback do
  @moduledoc "Runs plugin callbacks outside the plugin manager process."

  require Logger

  @default_timeout_ms 5_000

  @spec call(module(), atom(), [term()]) :: {:ok, term()} | {:error, term()}
  def call(module, callback, args) when is_atom(module) and is_atom(callback) and is_list(args) do
    task =
      Task.Supervisor.async_nolink(Vibe.TaskSupervisor, fn -> apply(module, callback, args) end)

    case Task.yield(task, timeout_ms()) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> {:ok, result}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  rescue
    error -> {:error, error}
  end

  @spec log_failure(module(), atom(), term(), term()) :: term()
  def log_failure(module, callback, reason, fallback \\ nil) do
    Logger.warning("Plugin #{inspect(module)} #{callback} failed: #{format_failure(reason)}")
    fallback
  end

  defp timeout_ms do
    Application.get_env(:vibe, :plugin_callback_timeout_ms, @default_timeout_ms)
  end

  defp format_failure(%{__struct__: _} = error), do: Exception.message(error)
  defp format_failure(reason), do: inspect(reason)
end
