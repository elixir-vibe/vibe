defmodule Exy.TUI.Widgets.Tools.Eval do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Markdown, ToolWidget}

  @impl true
  def render(tool, width, theme) do
    ToolWidget.block(tool, width, theme,
      name: :eval,
      action: timeout_summary(tool),
      summary: eval_summary(tool),
      output_lines: markdown_output_lines(tool, width, theme),
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

  defp markdown_output_lines(tool, width, theme) do
    with true <- markdown_eval?(tool),
         output when is_binary(output) <- ToolWidget.output(tool),
         {:ok, markdown} <- inspected_binary(output),
         true <- markdown?(markdown) do
      Markdown.render(markdown, max(width - 2, 1), theme)
    else
      _other -> nil
    end
  end

  defp markdown_eval?(tool) do
    tool
    |> Map.get(:args)
    |> code_from_args()
    |> case do
      code when is_binary(code) ->
        String.contains?(code, ["MD.to_markdown", "Exy.Markdown.to_markdown"])

      _other ->
        false
    end
  end

  defp inspected_binary(output) do
    case Code.string_to_quoted(output) do
      {:ok, binary} when is_binary(binary) -> {:ok, binary}
      _other -> :error
    end
  rescue
    _error -> :error
  end

  defp markdown?(markdown) do
    markdown = String.trim_leading(markdown)
    String.starts_with?(markdown, ["#", "- ", "* ", "```", ">", "|"])
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
