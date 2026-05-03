defmodule Exy.Tool.Display.AST do
  @moduledoc "Semantic display document for AST tool results."

  alias Exy.Tool.Display
  alias Exy.Tool.Display.Util

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    %Display{
      name: :ast,
      status: Map.get(tool, :status),
      summary: summary(tool, result),
      meta: meta(tool, result),
      body: [{:inspect, inspect(result, pretty: true), []}],
      expanded?: Util.expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp summary(tool, result) do
    action = tool |> Map.get(:args, %{}) |> Util.arg(:action)
    count = if is_list(result), do: length(result), else: nil

    [action, count && "#{count} matches"]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp meta(tool, result) do
    [action(tool), is_list(result) && "#{length(result)} results"]
    |> Enum.reject(&(&1 in [nil, false, ""]))
  end

  defp action(tool) do
    args = Map.get(tool, :args) || %{}

    case Util.arg(args, :action) do
      nil -> nil
      action -> to_string(action)
    end
  end
end
