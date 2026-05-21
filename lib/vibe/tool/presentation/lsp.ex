defmodule Vibe.Tool.Presentation.LSP do
  @moduledoc "Semantic display document for LSP tool results."

  alias Vibe.Tool.Presentation, as: Display
  alias Vibe.Tool.Presentation.Util

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    output = Map.get(tool, :output) || Map.get(tool, :result)

    %Display{
      name: :lsp,
      status: Map.get(tool, :status),
      summary: summary(tool, output),
      meta: meta(tool),
      body: body(output),
      expanded?: Util.expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp summary(tool, output) do
    args = Map.get(tool, :args) || %{}
    result = unwrap_result(output)

    cond do
      is_binary(Util.arg(args, :file)) -> Util.arg(args, :file)
      is_binary(Util.arg(args, :cwd)) -> Util.arg(args, :cwd)
      is_binary(Util.arg(args, :query)) -> Util.arg(args, :query)
      is_list(result) -> "#{length(result)} #{result_label(args)}"
      true -> Util.summarize_value(result, 72)
    end
  end

  defp meta(tool) do
    args = Map.get(tool, :args) || %{}

    [Util.arg(args, :action), wait_summary(args)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.map(&to_string/1)
  end

  defp wait_summary(args) do
    case Util.arg(args, :wait_ms) do
      milliseconds when is_integer(milliseconds) and rem(milliseconds, 1_000) == 0 ->
        "#{div(milliseconds, 1_000)}s"

      milliseconds when is_integer(milliseconds) ->
        "#{Float.round(milliseconds / 1_000, 1)}s"

      _wait ->
        nil
    end
  end

  defp body(%{error: error}), do: [{:error, to_string(error), truncation: :tail}]
  defp body(_output), do: []

  defp result_label(args) do
    case Util.arg(args, :action) do
      action when action in [:diagnostics, "diagnostics"] -> "diagnostics"
      _action -> "results"
    end
  end

  defp unwrap_result(%{result: result}), do: result
  defp unwrap_result(%{"result" => result}), do: result
  defp unwrap_result(output), do: output
end
