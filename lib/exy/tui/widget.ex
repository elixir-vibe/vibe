defmodule Exy.TUI.Widget do
  @moduledoc """
  Behaviour, renderer dispatch, and shared helpers for declarative TUI widgets.
  """

  alias Exy.TUI.{Node, Theme, Width}

  @type line :: IO.chardata()

  @callback render(Node.t(), pos_integer(), Theme.t()) :: [line()]

  @widgets %{
    vertical: Exy.TUI.Widgets.Vertical,
    raw: Exy.TUI.Widgets.Raw,
    text: Exy.TUI.Widgets.Text,
    markdown: Exy.TUI.Widgets.Markdown,
    message: Exy.TUI.Widgets.Message,
    loader: Exy.TUI.Widgets.Loader,
    tool: Exy.TUI.Widgets.Tool,
    section: Exy.TUI.Widgets.Section,
    status: Exy.TUI.Widgets.Status,
    model_info: Exy.TUI.Widgets.ModelInfo,
    input: Exy.TUI.Widgets.Input,
    textarea: Exy.TUI.Widgets.Textarea,
    select_list: Exy.TUI.Widgets.SelectList,
    notifications: Exy.TUI.Widgets.Notifications,
    plugin_widget: Exy.TUI.Widgets.PluginWidget,
    horizontal: Exy.TUI.Widgets.Horizontal,
    box: Exy.TUI.Widgets.Box,
    padding: Exy.TUI.Widgets.Padding,
    spacer: Exy.TUI.Widgets.Spacer,
    truncate: Exy.TUI.Widgets.Truncate,
    dialog: Exy.TUI.Widgets.Dialog,
    diff: Exy.TUI.Widgets.Diff,
    footer: Exy.TUI.Widgets.Footer,
    overlay: Exy.TUI.Widgets.Overlay
  }

  @spec render(Node.t() | IO.chardata(), pos_integer(), Theme.t()) :: [line()]
  def render(node, width, theme \\ Theme.default())

  def render(%Node{type: type} = node, width, theme) do
    renderer = widget!(type)
    renderer.render(node, width, theme)
  end

  def render(content, width, _theme), do: wrap(content, width)

  @spec wrap(IO.chardata(), pos_integer()) :: [line()]
  def wrap(content, width) do
    content
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.flat_map(&wrap_line(&1, width))
  end

  @spec fit_line(IO.chardata(), pos_integer()) :: line()
  def fit_line(line, width) do
    line = IO.iodata_to_binary(line)

    if Width.visible_length(line) <= width do
      line
    else
      Width.take(line, width)
    end
  end

  @spec repeat(IO.chardata(), integer()) :: IO.chardata()
  def repeat(content, count), do: List.duplicate(content, max(count, 0))

  @spec spaces(integer()) :: String.t()
  def spaces(count), do: IO.iodata_to_binary(repeat(" ", count))

  @spec pad_line(IO.chardata(), non_neg_integer()) :: line()
  def pad_line(line, width) do
    line = fit_line(line, width)
    [line, spaces(width - Width.visible_length(line))]
  end

  @spec background_line(IO.chardata(), pos_integer(), Theme.t(), atom(), keyword()) :: line()
  def background_line(content, width, theme, bg_key, opts \\ []) do
    padding_left = Keyword.get(opts, :padding_left, 0)
    fg_key = Keyword.get(opts, :fg)
    background = IO.iodata_to_binary(Theme.bg_start(theme, bg_key))
    reset = Theme.reset()
    content = content |> maybe_fg(theme, fg_key) |> preserve_background(background)
    content_width = Width.visible_length(content)
    remaining = max(width - padding_left - content_width, 0)

    [background, spaces(padding_left), content, spaces(remaining), reset]
  end

  @spec frame_line(IO.chardata(), pos_integer(), Theme.t()) :: line()
  def frame_line(content, width, theme) do
    inner_width = max(width - 4, 0)

    [
      Theme.fg(theme, :border, Theme.symbol(theme, :dialog_vertical)),
      " ",
      pad_line(content, inner_width),
      " ",
      Theme.fg(theme, :border, Theme.symbol(theme, :dialog_vertical))
    ]
  end

  @spec join_sides(IO.chardata(), IO.chardata(), pos_integer()) :: line()
  def join_sides(left, right, width) do
    left = IO.iodata_to_binary(left)
    right = IO.iodata_to_binary(right)
    minimum_gap = 2

    if Width.visible_length(left) + minimum_gap + Width.visible_length(right) <= width do
      [left, spaces(width - Width.visible_length(left) - Width.visible_length(right)), right]
    else
      fit_line([left, "  ", right], width)
    end
  end

  defp maybe_fg(content, _theme, nil), do: content
  defp maybe_fg(content, theme, fg_key), do: Theme.fg(theme, fg_key, content)

  defp preserve_background(content, background) do
    content
    |> IO.iodata_to_binary()
    |> String.replace(Theme.reset(), Theme.reset() <> background)
  end

  defp widget!(type), do: Map.fetch!(@widgets, type)

  defp wrap_line("", _width), do: [""]

  defp wrap_line(line, width) do
    cond do
      Width.visible_length(line) <= width ->
        [line]

      String.contains?(line, " ") ->
        word_wrap(line, width)

      true ->
        Width.chunks(line, width)
    end
  end

  defp word_wrap(line, width) do
    line
    |> String.split(~r/(\s+)/, include_captures: true, trim: true)
    |> Enum.flat_map(&split_long_wrap_part(&1, width))
    |> Enum.reduce([""], fn part, [current | rest] ->
      candidate = [current, part]
      current_text = IO.iodata_to_binary(current)

      cond do
        String.trim(current_text) == "" ->
          [String.trim_leading(part) | rest]

        Width.visible_length(candidate) <= width ->
          [candidate | rest]

        true ->
          [String.trim_leading(part), String.trim_trailing(current_text) | rest]
      end
    end)
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp split_long_wrap_part(part, width) do
    if String.trim(part) == "" or Width.visible_length(part) <= width do
      [part]
    else
      Width.chunks(part, width)
    end
  end
end
