defmodule Exy.Tool.Display.LSP do
  @moduledoc "Semantic display document for LSP tool results."

  alias Exy.Tool.Display
  alias Exy.Tool.Display.Util

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

    cond do
      is_binary(Util.arg(args, :file)) -> Util.arg(args, :file)
      is_binary(Util.arg(args, :cwd)) -> Util.arg(args, :cwd)
      is_binary(Util.arg(args, :query)) -> Util.arg(args, :query)
      is_list(output) -> "#{length(output)} diagnostics"
      true -> Util.summarize_value(output, 72)
    end
  end

  defp meta(tool) do
    args = Map.get(tool, :args) || %{}

    case Util.arg(args, :action) do
      nil -> []
      action -> [to_string(action)]
    end
  end

  defp body(%{error: error}), do: [{:error, to_string(error), truncation: :tail}]
  defp body(_output), do: []
end
