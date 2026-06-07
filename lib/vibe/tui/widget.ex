defmodule Vibe.TUI.Widget do
  @moduledoc """
  Behaviour, renderer dispatch, and shared helpers for declarative TUI widgets.
  """

  alias Vibe.TUI.Node
  alias Vibe.Terminal.TextLayout
  alias Vibe.Terminal.{Text, Theme, Width}

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
  def wrap(content, width), do: TextLayout.wrap(IO.iodata_to_binary(content), width)

  @spec fit_line(IO.chardata(), pos_integer()) :: line()
  def fit_line(line, width), do: fit_line(line, width, ellipsis?: false)

  @spec fit_line(IO.chardata(), pos_integer(), keyword()) :: line()
  def fit_line(line, width, opts) do
    line = Text.sanitize(line)

    if Width.visible_length(line) <= width do
      line
    else
      Cringe.Measure.fit(line, width, opts)
    end
  end

  @spec repeat(IO.chardata(), integer()) :: IO.chardata()
  def repeat(content, count), do: List.duplicate(content, max(count, 0))

  @spec spaces(integer()) :: String.t()
  def spaces(count), do: IO.iodata_to_binary(repeat(" ", count))

  @spec pad_line(IO.chardata(), non_neg_integer()) :: line()
  def pad_line(line, width) do
    line
    |> fit_line(width)
    |> IO.iodata_to_binary()
    |> Cringe.Measure.pad(width)
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
      | Vibe.Terminal.Lines.append(
          Enum.map(lines, &background_line(&1, width, theme, bg_key, opts)),
          blank
        )
    ]
  end

  @spec background_line(IO.chardata(), pos_integer(), Theme.t(), atom(), keyword()) :: line()
  def background_line(content, width, theme, bg_key, opts \\ []),
    do:
      TextLayout.background_line(
        content,
        width,
        theme,
        bg_key,
        Keyword.put_new(opts, :padding_left, 0)
      )

  @spec frame_line(IO.chardata(), pos_integer(), Theme.t()) :: line()
  def frame_line(content, width, theme) do
    inner_width = max(width - 4, 0)

    vertical = Theme.fg(theme, :border, Theme.symbol(theme, :dialog_vertical))

    [
      vertical,
      " ",
      pad_line(content, inner_width),
      " ",
      vertical
    ]
    |> background_line(width, theme, :input_bg)
  end

  @spec join_sides(IO.chardata(), IO.chardata(), pos_integer()) :: line()
  def join_sides(left, right, width), do: TextLayout.join_sides([left], [right], width)

  defp widget!(type), do: Map.fetch!(@widgets, type)
end
