defmodule Vibe.Terminal.Layout do
  @moduledoc "Terminal text layout helpers."

  alias Vibe.Terminal.TextLayout
  alias Vibe.Terminal.{Text, Theme, Width}

  @type line :: IO.chardata()

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

  @spec join_sides(IO.chardata(), IO.chardata(), pos_integer()) :: line()
  def join_sides(left, right, width), do: TextLayout.join_sides([left], [right], width)
end
