defmodule Exy.TUI.ToolWidget do
  @moduledoc """
  Behaviour and dispatcher for built-in tool widgets.
  """

  alias Exy.TUI.{DSL, Lines, TextTruncation, Theme, Widget}

  @type tool :: map()
  @type renderer :: module()

  @callback render(tool(), pos_integer(), Theme.t()) :: [IO.chardata()]

  @renderers %{
    elixir_eval: Exy.TUI.Widgets.Tools.Eval,
    elixir_ast: Exy.TUI.Widgets.Tools.AST,
    elixir_lsp: Exy.TUI.Widgets.Tools.LSP
  }

  @spec render(tool(), pos_integer(), Theme.t()) :: [IO.chardata()]
  def render(tool, width, theme) when is_map(tool) do
    tool
    |> tool_name()
    |> renderer()
    |> do_render(tool, width, theme)
  end

  @spec renderer(atom() | String.t() | nil) :: renderer()
  def renderer(name), do: Map.get(@renderers, normalize_name(name), Exy.TUI.Widgets.Tools.Generic)

  @spec block(tool(), pos_integer(), Theme.t(), keyword()) :: [IO.chardata()]
  def block(tool, width, theme, opts \\ []) do
    title = title(tool, theme, opts)

    sections =
      []
      |> maybe_append_params(tool, width, theme, opts)
      |> append_section(:output, output(tool), width, theme, tool)

    [title | sections]
  end

  @spec title(tool(), Theme.t(), keyword()) :: IO.chardata()
  def title(tool, theme, opts \\ []) do
    name = opts[:name] || tool_name(tool) || "tool"
    action = opts[:action]
    summary = opts[:summary]
    status = status(tool)

    text = [
      Theme.symbol(theme, :tool_icon),
      " ",
      to_string(name),
      if(action in [nil, ""], do: "", else: [" ", Theme.fg(theme, :muted, action)]),
      if(summary in [nil, ""],
        do: "",
        else: [Theme.symbol(theme, :separator), Theme.fg(theme, :dim, summary)]
      ),
      "  ",
      status_icon(status, theme),
      " ",
      to_string(status)
    ]

    theme |> Theme.fg(:tool_title, text) |> status_bg(status, theme)
  end

  @doc false
  def generic_lines(tool, width, theme),
    do: block(tool, width, theme, summary: compact_summary(tool))

  def compact_summary(tool) do
    cond do
      args = params(tool) -> summarize_value(args, 80)
      output = output(tool) -> summarize_value(output, 80)
      true -> nil
    end
  end

  def summarize_value(value, limit) when is_binary(value) do
    value |> String.replace("\n", " ") |> String.slice(0, limit)
  end

  def summarize_value(value, limit) do
    value |> inspect(limit: 8) |> String.replace("\n", " ") |> String.slice(0, limit)
  end

  def status_bg(text, status, theme) when status in [:ok, "ok", :success, "success"],
    do: Theme.bg(theme, :tool_success_bg, text)

  def status_bg(text, status, theme) when status in [:error, "error"],
    do: Theme.bg(theme, :tool_error_bg, text)

  def status_bg(text, _status, theme), do: Theme.bg(theme, :tool_pending_bg, text)

  def status(tool), do: tool |> Map.get(:status, :running) |> normalize_status()

  def status_icon(status, theme) when status in [:ok, "ok", :success, "success"],
    do: Theme.symbol(theme, :success_icon)

  def status_icon(status, theme) when status in [:error, "error"],
    do: Theme.symbol(theme, :error_icon)

  def status_icon(_status, theme), do: Theme.symbol(theme, :running_icon)

  def params(tool),
    do:
      Map.get(tool, :args) || Map.get(tool, "args") || Map.get(tool, :params) ||
        Map.get(tool, "params")

  def output(tool) do
    tool
    |> raw_output()
    |> unwrap_output()
  end

  def format_value(value) when is_binary(value), do: value
  def format_value(value), do: inspect(value, pretty: true, limit: 20)

  defp raw_output(tool),
    do:
      Map.get(tool, :output) || Map.get(tool, "output") || Map.get(tool, :result) ||
        Map.get(tool, "result")

  defp unwrap_output(%{output: output}), do: output
  defp unwrap_output(%{"output" => output}), do: output
  defp unwrap_output(output), do: output

  defp maybe_append_params(lines, tool, width, theme, opts) do
    if Keyword.get(opts, :params?, true) do
      append_section(lines, :params, params(tool), width, theme, tool)
    else
      lines
    end
  end

  defp append_section(lines, _label, nil, _width, _theme, _tool), do: lines

  defp append_section(lines, label, value, width, theme, tool) do
    label_lines =
      Widget.render(DSL.text([Theme.fg(theme, :muted, [to_string(label), ":"])]), width, theme)

    value_lines =
      value_lines(label, value, width, theme)
      |> maybe_truncate(label, tool, width, theme)

    lines |> Lines.join(label_lines) |> Lines.join(value_lines)
  end

  defp value_lines(:output, value, width, theme) do
    value
    |> format_value()
    |> highlight_output(theme)
    |> String.split("\n")
    |> Enum.flat_map(fn line -> Widget.wrap([Widget.spaces(2), line], width) end)
  end

  defp value_lines(_label, value, width, theme) do
    Widget.render(
      DSL.padding([DSL.text(format_value(value), fg: :tool_output)], x: 2),
      width,
      theme
    )
  end

  defp highlight_output(value, theme) do
    {:ok, highlighted} = Lumis.highlight(value, formatter: {:terminal, language: "elixir"})
    highlighted
  rescue
    _error -> Theme.fg(theme, :tool_output, value)
  end

  defp maybe_truncate(lines, :params, _tool, _width, _theme), do: lines

  defp maybe_truncate(lines, _label, tool, width, theme) do
    truncation = TextTruncation.lines(lines, enabled?: Map.get(tool, :truncate?, true), limit: 8)

    if truncation.truncated? do
      Lines.join(truncation.lines, [TextTruncation.hint(truncation.omitted, theme, width)])
    else
      truncation.lines
    end
  end

  defp do_render(renderer, tool, width, theme), do: renderer.render(tool, width, theme)

  defp tool_name(tool), do: Map.get(tool, :name) || Map.get(tool, "name")

  defp normalize_name(name) when is_atom(name), do: name

  defp normalize_name(name) when is_binary(name) do
    name
    |> String.replace("-", "_")
    |> String.to_existing_atom()
  rescue
    ArgumentError -> nil
  end

  defp normalize_name(_name), do: nil

  defp normalize_status(:success), do: :ok
  defp normalize_status("success"), do: :ok
  defp normalize_status(status), do: status
end
