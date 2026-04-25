defmodule Exy.Actions.Result do
  @moduledoc false

  @spec run((-> {:ok, term()} | {:error, term()} | term())) :: {:ok, term()}
  def run(fun) when is_function(fun, 0) do
    fun.()
    |> normalize()
  rescue
    error ->
      {:ok,
       %{error: Exception.format(:error, error, __STACKTRACE__) |> Exy.ToolOutput.limit_text()}}
  catch
    kind, reason ->
      {:ok,
       %{error: Exception.format(kind, reason, __STACKTRACE__) |> Exy.ToolOutput.limit_text()}}
  end

  defp normalize({:ok, result}), do: {:ok, result}

  defp normalize({:error, error}) when is_binary(error),
    do: {:ok, %{error: Exy.ToolOutput.limit_text(error)}}

  defp normalize({:error, error}), do: {:ok, %{error: inspect(error, pretty: true, limit: 20)}}
  defp normalize(result), do: {:ok, result}
end
