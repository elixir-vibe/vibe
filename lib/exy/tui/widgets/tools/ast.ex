defmodule Exy.TUI.Widgets.Tools.AST do
  @moduledoc false

  @behaviour Exy.TUI.ToolWidget

  alias Exy.TUI.{Lines, Markdown, Theme, ToolWidget, Widget}

  @impl true
  def render(tool, width, theme) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    ToolWidget.block(tool, width, theme,
      name: :ast,
      action: action(tool),
      summary: summary(tool, result),
      meta: meta(tool, result),
      params?: false,
      output_lines: output_lines(result, max(width - 2, 1), theme)
    )
  end

  defp action(tool) do
    case args(tool) do
      %{action: action} -> to_string(action)
      %{"action" => action} -> to_string(action)
      _args -> nil
    end
  end

  defp summary(tool, _result) do
    args = args(tool)
    path = get_arg(args, :path) || get_arg(args, :file)

    cond do
      is_binary(path) -> path
      pattern = get_arg(args, :pattern) -> pattern
      true -> nil
    end
  end

  defp meta(tool, %Exy.Code.AST.Result{} = result) do
    args = args(tool)

    case result.action do
      :search ->
        compact([pattern_meta(args), match_meta(result.result)])

      :replace ->
        compact([replacement_meta(args), match_meta(result.result), dry_run_meta(result)])

      :diff ->
        compact([edit_meta(result.result)])

      _action ->
        []
    end
  end

  defp meta(tool, result), do: compact([pattern_meta(args(tool)), collapsed_summary(result)])

  defp output_lines(%Exy.Code.AST.Result{action: :search} = result, width, theme),
    do: search_lines(result, width, theme)

  defp output_lines(%Exy.Code.AST.Result{action: :replace, diff: diff} = result, width, theme) do
    result
    |> replace_summary_lines(width, theme)
    |> Lines.join(diff_lines(diff, width, theme))
  end

  defp output_lines(result, width, theme) when is_list(result),
    do: search_lines(%{result: result}, width, theme)

  defp output_lines(%Exy.Code.AST.Result{} = result, width, theme) do
    result
    |> Exy.Markdown.to_markdown()
    |> Markdown.render(width, theme)
  end

  defp output_lines(_result, _width, _theme), do: nil

  defp search_lines(%{result: matches}, width, theme) when is_list(matches) do
    matches
    |> Enum.take(20)
    |> Enum.flat_map(fn match ->
      match
      |> match_location()
      |> then(&Widget.wrap([Widget.spaces(2), Theme.fg(theme, :tool_output, &1)], width))
    end)
    |> maybe_append_omitted(length(matches), width, theme)
  end

  defp replace_summary_lines(result, width, theme) do
    ["matches: #{match_count(result.result)}", "dry-run: #{inspect(result.dry_run)}"]
    |> Enum.flat_map(&detail_line(&1, width, theme))
  end

  defp diff_lines(diff, width, theme) do
    diff
    |> List.wrap()
    |> Enum.flat_map(fn %{path: path, diff: diff} ->
      header = detail_line(path, width, theme)

      rendered_diff =
        Exy.TUI.diff(text: diff)
        |> Widget.render(max(width - 2, 1), theme)
        |> Enum.map(&[Widget.spaces(2), &1])

      header |> Lines.join(rendered_diff)
    end)
  end

  defp detail_line(text, width, theme),
    do: Widget.wrap([Widget.spaces(2), Theme.fg(theme, :muted, text)], width)

  defp maybe_append_omitted(lines, total, _width, _theme) when total <= 20, do: lines

  defp maybe_append_omitted(lines, total, width, theme) do
    Lines.join(lines, detail_line("… #{total - 20} more matches", width, theme))
  end

  defp match_location(%{file: file, line: line}), do: "#{file}:#{line}"
  defp match_location(%{path: path, line: line}), do: "#{path}:#{line}"
  defp match_location({file, line}) when is_binary(file), do: "#{file}:#{line}"
  defp match_location(match), do: ToolWidget.summarize_value(match, 100)

  defp replacement_meta(args) do
    pattern = get_arg(args, :pattern)
    replacement = get_arg(args, :replacement)

    cond do
      is_binary(pattern) and is_binary(replacement) -> "#{short(pattern)} → #{short(replacement)}"
      is_binary(pattern) -> "pattern: #{short(pattern)}"
      true -> nil
    end
  end

  defp pattern_meta(args) do
    case get_arg(args, :pattern) do
      pattern when is_binary(pattern) -> "pattern: #{short(pattern)}"
      _pattern -> nil
    end
  end

  defp dry_run_meta(%{dry_run: true}), do: "dry-run"
  defp dry_run_meta(_result), do: nil

  defp match_meta(matches), do: plural(match_count(matches), "match")

  defp edit_meta(%{edits: edits}) when is_list(edits), do: plural(length(edits), "edit")
  defp edit_meta(_result), do: nil

  defp match_count(matches) when is_list(matches) do
    matches
    |> Enum.map(fn
      {_path, count} -> count
      _other -> 1
    end)
    |> Enum.sum()
  end

  defp match_count(_matches), do: 0

  defp plural(1, word), do: "1 #{word}"
  defp plural(count, word), do: "#{count} #{word}s"

  defp short(value), do: ToolWidget.summarize_value(value, 48)

  defp compact(values), do: Enum.reject(values, &(&1 in [nil, ""]))

  defp get_arg(args, key) do
    Map.get(args, key) || Map.get(args, to_string(key))
  end

  defp args(tool), do: Map.get(tool, :args) || %{}

  defp collapsed_summary(matches) when is_list(matches), do: plural(length(matches), "match")
  defp collapsed_summary(value), do: ToolWidget.summarize_value(value, 72)
end
