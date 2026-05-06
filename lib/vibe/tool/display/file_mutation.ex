defmodule Vibe.Tool.Display.FileMutation do
  @moduledoc "Semantic display document for file mutation tools."

  alias Vibe.Tool.Display
  alias Vibe.Tool.Display.Util

  @spec from_tool(map(), :write | :edit) :: Display.t()
  def from_tool(tool, name) when name in [:write, :edit] do
    result = Util.tool_output(tool)

    %Display{
      name: name,
      status: Map.get(tool, :status),
      summary: Util.path_summary(tool, result),
      body: body(result, name),
      expanded?: Util.expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp body(%{change: %{diff: diff}} = result, :edit) when is_binary(diff) do
    [{:diff, diff, language: Util.language_from_path(Map.get(result, :path))}]
  end

  defp body(%{diff: diff} = result, :edit) when is_binary(diff) do
    [{:diff, diff, language: Util.language_from_path(Map.get(result, :path))}]
  end

  defp body(%{change: %{new: source}} = result, :write) when is_binary(source) do
    [{:source, source, language: Util.language_from_path(Map.get(result, :path))}]
  end

  defp body(result, _name) do
    [{:inspect, inspect(result, pretty: true), []}]
  end
end
