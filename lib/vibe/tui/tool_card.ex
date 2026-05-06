defmodule Vibe.TUI.ToolCard do
  @moduledoc "Renders the shared card shell and title for TUI tool output."

  alias Vibe.TUI.{Syntax, Theme, Widget, Width}

  @type tool :: map()

  @spec block(tool(), pos_integer(), Theme.t(), [IO.chardata()], keyword()) :: [IO.chardata()]
  def block(tool, width, theme, sections, opts \\ []) do
    inner_width = max(width - 2, 1)
    title = title(tool, inner_width, theme, opts)

    [title | sections]
    |> Enum.map(&Widget.inset_line(&1, width))
  end

  @spec title(tool(), Theme.t(), keyword()) :: IO.chardata()
  def title(tool, theme, opts \\ []), do: title(tool, nil, theme, opts)

  @spec title(tool(), pos_integer() | nil, Theme.t(), keyword()) :: IO.chardata()
  def title(tool, width, theme, opts) do
    name = opts[:name] || Map.get(tool, :name) || "tool"
    action = opts[:action]
    summary = opts[:summary]
    meta = opts |> Keyword.get(:meta, []) |> Enum.reject(&(&1 in [nil, ""]))
    status = status(tool)

    prefix = [
      Theme.fg(theme, :tool_icon, Theme.symbol(theme, :tool_icon)),
      " ",
      Theme.bold(to_string(name))
    ]

    suffix = ["  ", status_icon(status, theme)]

    headline =
      fitted_headline(
        summary,
        meta,
        Keyword.get(opts, :summary_style),
        prefix,
        action,
        suffix,
        width,
        theme
      )

    text = [
      prefix,
      if(action in [nil, ""], do: "", else: [" ", action]),
      if(headline in [nil, ""], do: "", else: [Theme.symbol(theme, :separator), headline]),
      suffix
    ]

    Theme.fg(theme, :tool_title, text)
  end

  @spec status_bg(IO.chardata(), term(), Theme.t()) :: IO.chardata()
  def status_bg(text, status, theme) when status in [:ok, "ok", :success, "success"],
    do: Theme.bg(theme, :tool_success_bg, text)

  def status_bg(text, :error, theme), do: Theme.bg(theme, :tool_error_bg, text)
  def status_bg(text, _status, theme), do: Theme.bg(theme, :tool_pending_bg, text)

  @spec status(tool()) :: atom() | String.t()
  def status(tool), do: tool |> Map.get(:status, :running) |> normalize_status()

  @spec status_icon(term(), Theme.t()) :: IO.chardata()
  def status_icon(status, theme) when status in [:ok, :success],
    do: Theme.fg(theme, :success, Theme.symbol(theme, :success_icon))

  def status_icon(:error, theme), do: Theme.fg(theme, :error, Theme.symbol(theme, :error_icon))
  def status_icon(_status, theme), do: Theme.fg(theme, :muted, Theme.symbol(theme, :running_icon))

  defp format_summary(summary, :elixir_dim) when is_binary(summary),
    do: Syntax.highlight_inline_elixir(summary)

  defp format_summary(summary, _style), do: summary

  defp fitted_headline(summary, meta, summary_style, prefix, action, suffix, width, theme) do
    summary = format_summary(summary, summary_style)
    meta = Enum.map(meta, &Theme.fg(theme, :muted, &1))
    headline = join_headline(summary, meta, theme)

    cond do
      headline in [nil, "", []] -> headline
      is_nil(width) -> headline
      true -> fit_headline(summary, meta, prefix, action, suffix, width, theme)
    end
  end

  defp join_headline(summary, meta, theme) do
    [summary | meta]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.intersperse([" ", Theme.fg(theme, :muted, "·"), " "])
  end

  defp fit_headline(summary, meta, prefix, action, suffix, width, theme) do
    separator_width = Width.visible_length(Theme.symbol(theme, :separator))
    action_width = if action in [nil, ""], do: 0, else: Width.visible_length([" ", action])

    available =
      width - Width.visible_length(prefix) - action_width - Width.visible_length(suffix) -
        separator_width

    cond do
      available <= 0 ->
        nil

      meta == [] ->
        Widget.fit_line(summary, available, ellipsis?: true)

      summary in [nil, ""] ->
        Widget.fit_line(join_headline(nil, meta, theme), available, ellipsis?: true)

      true ->
        meta_tail = [
          " ",
          Theme.fg(theme, :muted, "·"),
          " ",
          Enum.intersperse(meta, [" ", Theme.fg(theme, :muted, "·"), " "])
        ]

        summary_available = available - Width.visible_length(meta_tail)

        if summary_available > 0 do
          [Widget.fit_line(summary, summary_available, ellipsis?: true), meta_tail]
        else
          Widget.fit_line(join_headline(summary, meta, theme), available, ellipsis?: true)
        end
    end
  end

  defp normalize_status(:success), do: :ok
  defp normalize_status(status), do: status
end
