defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.ToolWidget

  @impl true
  def render(tool, width, theme) do
    ToolWidget.block(tool, width, theme, name: :elixir_eval, summary: eval_summary(tool))
  end

  defp eval_summary(tool) do
    cond do
      code = Map.get(tool, :code) -> ToolWidget.summarize_value(code, 72)
      args = Map.get(tool, :args) -> args |> code_from_args() |> ToolWidget.summarize_value(72)
      true -> ToolWidget.compact_summary(tool)
    end
  end

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(args), do: args
end
