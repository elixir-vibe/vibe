defmodule Vibe.Plugin.Manager.Pipeline do
  @moduledoc "Composes ordered plugin pipeline callbacks."

  @type plugin_entry :: {module(), %{state: term()}}

  @spec run([plugin_entry()], atom(), term(), map(), term(), function(), function(), function()) ::
          {:ok, term()} | {{:ok, term()} | {:block, term()}, term()}
  def run(
        plugins,
        callback,
        initial_value,
        context,
        state,
        call_plugin,
        put_plugin_state,
        log_failure
      ) do
    plugins
    |> Enum.reduce_while({:ok, initial_value, false, state}, fn {module, entry}, acc ->
      step(module, entry, callback, context, acc, call_plugin, put_plugin_state, log_failure)
    end)
    |> reply()
  end

  defp step(
         module,
         entry,
         callback,
         context,
         {:ok, value, changed?, state},
         call_plugin,
         put_plugin_state,
         log_failure
       ) do
    with true <- function_exported?(module, callback, 3),
         {:ok, reply} <- call_plugin.(module, callback, [value, context, entry.state]) do
      case reply do
        {:ok, new_state} ->
          {:cont, {:ok, value, changed?, put_plugin_state.(state, module, new_state)}}

        {:ok, modified, new_state} ->
          {:cont, {:ok, modified, true, put_plugin_state.(state, module, new_state)}}

        {:block, reason, new_state} ->
          {:halt, {{:block, reason}, put_plugin_state.(state, module, new_state)}}
      end
    else
      false ->
        {:cont, {:ok, value, changed?, state}}

      {:error, reason} ->
        log_failure.(module, callback, reason)
        {:cont, {:ok, value, changed?, state}}
    end
  end

  defp reply({:ok, _value, false, state}), do: {:ok, state}
  defp reply({:ok, value, true, state}), do: {{:ok, value}, state}
  defp reply({{:block, reason}, state}), do: {{:block, reason}, state}
end
