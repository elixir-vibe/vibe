defmodule Vibe.Tool.PluginHooks do
  @moduledoc "Applies plugin tool-call and tool-result hooks around model-facing tools."

  alias Vibe.Tool.AdapterResult

  @spec run(atom(), term(), term(), (term() -> AdapterResult.raw_result())) ::
          AdapterResult.tool_result()
  def run(name, params, context, fun) when is_atom(name) and is_function(fun, 1) do
    AdapterResult.run(fn ->
      if is_map(params) do
        with {:ok, params} <- prepare_call(name, params, context) do
          params
          |> fun.()
          |> apply_result_hook(name, context)
        end
      else
        fun.(params)
      end
    end)
  end

  defp prepare_call(name, params, context) do
    call = %{name: name, args: params}

    case tool_call(call, context) do
      :ok -> {:ok, params}
      {:ok, %{args: args}} when is_map(args) -> {:ok, args}
      {:ok, modified} when is_map(modified) -> {:ok, Map.get(modified, :args, params)}
      {:block, reason} -> {:error, {:blocked, reason}}
    end
  end

  defp apply_result_hook(result, name, context) do
    result_payload = %{name: name, result: result_output(result), raw_result: result}

    case tool_result(result_payload, context) do
      :ok -> result
      {:ok, %{raw_result: raw_result}} -> raw_result
      {:ok, %{result: modified}} -> {:ok, modified}
      {:ok, modified} -> {:ok, modified}
    end
  end

  defp result_output({:ok, result}), do: result
  defp result_output({:error, error}), do: %{error: error}
  defp result_output(result), do: result

  defp tool_call(call, context) do
    if Process.whereis(Vibe.Plugin.Manager),
      do: Vibe.Plugin.Manager.tool_call(call, tool_context(context)),
      else: :ok
  rescue
    error ->
      require Logger
      Logger.warning("Plugin tool_call hook failed: #{Exception.message(error)}")
      :ok
  end

  defp tool_result(result, context) do
    if Process.whereis(Vibe.Plugin.Manager),
      do: Vibe.Plugin.Manager.tool_result(result, tool_context(context)),
      else: :ok
  rescue
    error ->
      require Logger
      Logger.warning("Plugin tool_result hook failed: #{Exception.message(error)}")
      :ok
  end

  defp tool_context(context) when is_map(context), do: context
  defp tool_context(_context), do: %{}
end
