defmodule Exy.TUI.Widgets.Tools.LSP do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Duration, ToolWidget}

  @impl true
  def render(tool, width, theme) do
    output = Map.get(tool, :output) || Map.get(tool, :result)

    ToolWidget.block(tool, width, theme,
      name: :lsp,
      action: action(tool),
      summary: summary(tool, output),
      params?: false
    )
  end

  def meta(tool) do
    case action(tool) do
      nil -> []
      action -> [action]
    end
  end

  defp action(tool) do
    tool
    |> args()
    |> then(fn args -> [action_name(args), wait_summary(args)] end)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> nil
      action -> action
    end
  end

  defp action_name(%{action: action}), do: to_string(action)
  defp action_name(%{"action" => action}), do: to_string(action)
  defp action_name(_args), do: nil

  defp wait_summary(%{wait_ms: wait_ms}), do: format_wait(wait_ms)
  defp wait_summary(%{"wait_ms" => wait_ms}), do: format_wait(wait_ms)
  defp wait_summary(_args), do: nil

  defp format_wait(wait_ms), do: Duration.milliseconds(wait_ms)

  def summary(tool, output) do
    case {args(tool), output} do
      {%{file: file}, _output} when is_binary(file) -> file
      {%{"file" => file}, _output} when is_binary(file) -> file
      {%{cwd: cwd}, _output} when is_binary(cwd) -> cwd
      {%{"cwd" => cwd}, _output} when is_binary(cwd) -> cwd
      {%{query: query}, _output} when is_binary(query) -> query
      {%{"query" => query}, _output} when is_binary(query) -> query
      {_args, output} -> collapsed_summary(output)
    end
  end

  defp args(tool), do: Map.get(tool, :args) || %{}

  defp collapsed_summary([]), do: "0 diagnostics"
  defp collapsed_summary(list) when is_list(list), do: "#{length(list)} diagnostics"
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)
end
