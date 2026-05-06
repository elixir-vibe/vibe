defmodule Vibe.Actions.ToolResult do
  @moduledoc "Tool result struct for Jido action outputs."
  @type raw_result :: {:ok, term()} | {:error, term()} | term()
  @type tool_result :: {:ok, term()}

  @spec run((-> raw_result())) :: tool_result()
  def run(fun) when is_function(fun, 0) do
    fun.()
    |> to_tool_result()
  rescue
    error -> Exception.format(:error, error, __STACKTRACE__) |> error_result()
  catch
    kind, reason -> Exception.format(kind, reason, __STACKTRACE__) |> error_result()
  end

  @spec ok(term()) :: tool_result()
  def ok(result), do: {:ok, result}

  @spec error(term()) :: tool_result()
  def error(error), do: error |> format_error() |> error_result()

  defp to_tool_result({:ok, result}), do: ok(result)
  defp to_tool_result({:error, error}), do: error(error)
  defp to_tool_result(result), do: ok(result)

  defp error_result(message), do: ok(%{error: Vibe.ToolOutput.limit_text(message)})

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error, pretty: true, limit: 20)
end
