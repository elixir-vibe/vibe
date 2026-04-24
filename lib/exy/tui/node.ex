defmodule Exy.TUI.Node do
  @moduledoc """
  Declarative TUI node tree rendered to iodata lines.
  """

  alias Exy.TUI.{Theme, Width}

  defstruct [:type, props: %{}, children: []]

  @type t :: %__MODULE__{type: atom(), props: map(), children: [t() | IO.chardata()]}
  @type line :: IO.chardata()

  @spec vertical([t() | IO.chardata()]) :: t()
  def vertical(children), do: %__MODULE__{type: :vertical, children: List.wrap(children)}

  @spec raw(IO.chardata()) :: t()
  def raw(content), do: %__MODULE__{type: :raw, children: [content]}

  @spec text(IO.chardata(), keyword() | map()) :: t()
  def text(content, opts \\ []),
    do: %__MODULE__{type: :text, props: Map.new(opts), children: [content]}

  @spec footer(map() | struct()) :: t()
  def footer(footer), do: %__MODULE__{type: :footer, props: to_props(footer)}

  @spec message(map() | struct()) :: t()
  def message(message), do: %__MODULE__{type: :message, props: to_props(message)}

  @spec tool(map() | struct()) :: t()
  def tool(tool), do: %__MODULE__{type: :tool, props: to_props(tool)}

  @spec overlay(map() | struct()) :: t()
  def overlay(overlay), do: %__MODULE__{type: :overlay, props: to_props(overlay)}

  @spec render(t() | IO.chardata(), pos_integer(), Theme.t()) :: [line()]
  def render(node, width, theme \\ Theme.default())

  def render(%__MODULE__{type: :vertical, children: children}, width, theme) do
    Enum.flat_map(children, &render(&1, width, theme))
  end

  def render(%__MODULE__{type: :raw, children: [content]}, width, _theme),
    do: wrap(content, width)

  def render(%__MODULE__{type: :text, props: props, children: [content]}, width, theme) do
    content
    |> style(props, theme)
    |> wrap(width)
  end

  def render(%__MODULE__{type: :message, props: %{role: :user, text: text}}, width, theme) do
    prefix = Theme.fg(theme, :accent, "You: ")
    wrap([prefix, Theme.fg(theme, :user_message_text, to_string(text))], width)
  end

  def render(%__MODULE__{type: :message, props: %{error: error}}, width, theme)
      when is_binary(error) do
    wrap(Theme.fg(theme, :error, ["Exy error: ", error]), width)
  end

  def render(%__MODULE__{type: :message, props: %{role: :assistant} = props}, width, theme) do
    prefix = Theme.fg(theme, :success, "Exy: ")

    wrap(
      [prefix, Theme.fg(theme, :assistant_message_text, to_string(Map.get(props, :text) || ""))],
      width
    )
  end

  def render(%__MODULE__{type: :message, props: %{text: text}}, width, theme) do
    prefix = Theme.fg(theme, :accent, "You: ")
    wrap([prefix, Theme.fg(theme, :user_message_text, to_string(text))], width)
  end

  def render(%__MODULE__{type: :tool, props: props}, width, theme) do
    Exy.TUI.ToolWidget.render(props, width, theme)
  end

  def render(%__MODULE__{type: :footer, props: props}, width, theme) do
    usage = Map.get(props, :usage, %{}) || %{}
    tokens = Map.get(usage, :total_tokens, 0)
    left = "#{short_cwd(Map.get(props, :cwd))} • #{Map.get(props, :session_id)}"
    right = "#{Map.get(props, :model)} • #{Map.get(props, :status)} • #{tokens} tok"
    [Theme.fg(theme, :dim, join_sides(left, right, width))]
  end

  def render(%__MODULE__{type: :overlay, props: %{kind: kind}}, width, theme) do
    [kind |> then(&["Overlay: ", to_string(&1)]) |> fit_line(width) |> Theme.fg(theme, :accent)]
  end

  def render(content, width, _theme), do: wrap(content, width)

  defp to_props(%_{} = struct), do: Map.from_struct(struct)
  defp to_props(map) when is_map(map), do: map

  defp style(content, props, theme) do
    content
    |> maybe_style(props, theme, :fg, &Theme.fg/3)
    |> maybe_style(props, theme, :bg, &Theme.bg/3)
  end

  defp maybe_style(content, props, theme, key, fun) do
    case Map.get(props, key) do
      nil -> content
      color -> fun.(theme, color, content)
    end
  end

  defp wrap(content, width) do
    content
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.flat_map(&wrap_line(&1, width))
  end

  defp wrap_line("", _width), do: [""]

  defp wrap_line(line, width) do
    if Width.visible_length(line) <= width do
      [line]
    else
      line
      |> Width.visible_text()
      |> String.graphemes()
      |> Enum.chunk_every(width)
      |> Enum.map(&Enum.join/1)
    end
  end

  defp join_sides(left, right, width) do
    left = to_string(left)
    right = to_string(right)
    minimum_gap = 2

    if Width.visible_length(left) + minimum_gap + Width.visible_length(right) <= width do
      [
        left,
        String.duplicate(" ", width - Width.visible_length(left) - Width.visible_length(right)),
        right
      ]
    else
      fit_line([left, "  ", right], width)
    end
  end

  defp fit_line(line, width) do
    line = IO.iodata_to_binary(line)

    if Width.visible_length(line) <= width do
      line
    else
      line |> Width.visible_text() |> String.graphemes() |> Enum.take(width) |> Enum.join()
    end
  end

  defp short_cwd(nil), do: ""

  defp short_cwd(cwd) do
    home = System.user_home!()

    if String.starts_with?(cwd, home), do: "~" <> String.replace_prefix(cwd, home, ""), else: cwd
  end
end
