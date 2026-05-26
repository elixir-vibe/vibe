defmodule Vibe.Terminal.Layout do
  @moduledoc "Terminal text layout helpers."

  alias Vibe.Terminal.{Text, Theme, Width}

  @type line :: IO.chardata()

  @spec wrap(IO.chardata(), pos_integer()) :: [line()]
  def wrap(content, width) do
    content
    |> Text.sanitize()
    |> Cringe.Measure.wrap(width)
  end

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
end
