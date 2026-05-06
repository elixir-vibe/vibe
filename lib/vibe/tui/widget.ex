defmodule Vibe.TUI.Widget do
  @moduledoc """
  Behaviour, renderer dispatch, and shared helpers for declarative TUI widgets.
  """

  alias Vibe.TUI.{Node, TerminalText, Theme, Width}

  @type line :: IO.chardata()

  @callback render(Node.t(), pos_integer(), Theme.t()) :: [line()]

  @widgets %{
    vertical: Vibe.TUI.Widgets.Vertical,
    raw: Vibe.TUI.Widgets.Raw,
    text: Vibe.TUI.Widgets.Text,
    markdown: Vibe.TUI.Widgets.Markdown,
    image: Vibe.TUI.Widgets.Image,
    message: Vibe.TUI.Widgets.Message,
    loader: Vibe.TUI.Widgets.Loader,
    tool: Vibe.TUI.Widgets.Tool,
    section: Vibe.TUI.Widgets.Section,
    status: Vibe.TUI.Widgets.Status,
    model_info: Vibe.TUI.Widgets.ModelInfo,
    input: Vibe.TUI.Widgets.Input,
    textarea: Vibe.TUI.Widgets.Textarea,
    autocomplete: Vibe.TUI.Widgets.Autocomplete,
    select_list: Vibe.TUI.Widgets.SelectList,
    notifications: Vibe.TUI.Widgets.Notifications,
    plugin_widget: Vibe.TUI.Widgets.PluginWidget,
    horizontal: Vibe.TUI.Widgets.Horizontal,
    box: Vibe.TUI.Widgets.Box,
    padding: Vibe.TUI.Widgets.Padding,
    spacer: Vibe.TUI.Widgets.Spacer,
    truncate: Vibe.TUI.Widgets.Truncate,
    dialog: Vibe.TUI.Widgets.Dialog,
    confirmation: Vibe.TUI.Widgets.Confirmation,
    diff: Vibe.TUI.Widgets.Diff,
    footer: Vibe.TUI.Widgets.Footer,
    overlay: Vibe.TUI.Widgets.Overlay
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
    |> TerminalText.sanitize()
    |> String.split("\n")
    |> Enum.flat_map(&wrap_line(&1, width))
  end

  @spec fit_line(IO.chardata(), pos_integer()) :: line()
  def fit_line(line, width), do: fit_line(line, width, ellipsis?: false)

  @spec fit_line(IO.chardata(), pos_integer(), keyword()) :: line()
  def fit_line(line, width, opts) do
    line = TerminalText.sanitize(line)

    cond do
      Width.visible_length(line) <= width ->
        line

      Keyword.get(opts, :ellipsis?, false) and width > 0 ->
        [Width.take(line, max(width - 1, 0)), "…"]

      true ->
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

  @spec inset_line(IO.chardata(), non_neg_integer()) :: line()
  def inset_line(content, width) do
    inner_width = max(width - 2, 1)
    [" ", pad_line(content, inner_width), " "]
  end

  @spec block_lines([IO.chardata()], pos_integer(), Theme.t(), atom(), keyword()) :: [line()]
  def block_lines(lines, width, theme, bg_key, opts \\ []) when is_list(lines) do
    blank = background_line("", width, theme, bg_key, opts)

    [
      blank
      | Vibe.TUI.Lines.append(
          Enum.map(lines, &background_line(&1, width, theme, bg_key, opts)),
          blank
        )
    ]
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
    |> background_line(width, theme, :input_bg)
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
