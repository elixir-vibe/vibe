defmodule Exy.Tool.Display.Read do
  @moduledoc "Internal implementation module."
  alias Exy.Tool.Display
  alias Exy.TUI.Widgets.Tools.FileTool

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    result = Exy.TUI.ToolWidget.output(tool)
    expanded? = Map.get(tool, :expanded?, false) or Map.get(tool, :truncate?) == false

    %Display{
      name: :read,
      status: Map.get(tool, :status),
      summary: FileTool.path_summary(tool, result),
      body: body(result),
      expanded?: expanded?,
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp body(%{error: error}), do: [{:error, to_string(error), []}]

  defp body(%{content: content} = result) when is_binary(content) do
    kind = if markdown?(result), do: :markdown, else: :source

    opts = [
      language: Map.get(result, :language),
      read_limit_truncated?: read_limit_truncated?(result),
      truncation: :head
    ]

    [{kind, content, opts}]
  end

  defp body(value), do: [{:text, Exy.TUI.ToolWidget.format_value(value), []}]

  defp read_limit_truncated?(result),
    do: Map.get(result, :omitted_lines, 0) > 0 or Map.get(result, :omitted_bytes, 0) > 0

  defp markdown?(%{language: language}) when is_binary(language),
    do: language in ["markdown", "md"]

  defp markdown?(%{path: path}) when is_binary(path),
    do: String.downcase(Path.extname(path)) in [".md", ".markdown"]

  defp markdown?(_result), do: false
end
