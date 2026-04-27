defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme) do
    ToolWidget.block(tool, width, theme,
      name: :eval,
      action: timeout_summary(tool),
      summary: eval_summary(tool),
      command: expanded_command(tool),
      params?: false
    )
  end

  defp eval_summary(tool) do
    cond do
      code = Map.get(tool, :code) ->
        ToolWidget.summarize_value(code, :infinity)

      args = Map.get(tool, :args) ->
        args |> code_from_args() |> ToolWidget.summarize_value(:infinity)

      true ->
        ToolWidget.compact_summary(tool)
    end
  end

  defp expanded_command(%{truncate?: false} = tool), do: command(tool)
  defp expanded_command(_tool), do: nil

  defp command(tool) do
    cond do
      code = Map.get(tool, :code) -> code
      args = Map.get(tool, :args) -> code_from_args(args)
      true -> nil
    end
  end

  defp timeout_summary(tool) do
    case Map.get(tool, :args) || %{} do
      %{timeout: timeout} -> format_timeout(timeout)
      %{"timeout" => timeout} -> format_timeout(timeout)
      _args -> nil
    end
  end

  defp format_timeout(timeout) when is_integer(timeout) and rem(timeout, 1000) == 0,
    do: "#{div(timeout, 1000)}s"

  defp format_timeout(timeout) when is_integer(timeout), do: "#{Float.round(timeout / 1000, 1)}s"
  defp format_timeout(timeout), do: to_string(timeout)

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(args), do: args
end
