defmodule Vibe.Terminal.TextLayout do
  @moduledoc "ANSI-preserving terminal text wrapping for presentation surfaces."

  alias Vibe.Terminal.{Text, Theme, Width}

  @spec wrap(IO.chardata(), pos_integer()) :: [String.t()]
  def wrap(content, width) do
    content = Text.sanitize(content)

    if ansi?(content) do
      wrap_ansi(content, width)
    else
      Cringe.Measure.wrap(content, width)
    end
  end

  @spec background_line(IO.chardata(), pos_integer(), Theme.t(), atom(), keyword()) ::
          IO.chardata()
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

  @spec join_sides(IO.chardata(), IO.chardata(), pos_integer()) :: IO.chardata()
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

  @spec fit_line(IO.chardata(), non_neg_integer(), keyword()) :: IO.chardata()
  def fit_line(line, width, opts \\ []) do
    line = Text.sanitize(line)

    if Width.visible_length(line) <= width do
      line
    else
      Cringe.Measure.fit(line, width, opts)
    end
  end

  @spec spaces(integer()) :: String.t()
  def spaces(count), do: IO.iodata_to_binary(List.duplicate(" ", max(count, 0)))

  defp wrap_ansi(content, width) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&wrap_ansi_line(&1, width))
  end

  defp wrap_ansi_line("", _width), do: [""]

  defp wrap_ansi_line(line, width) do
    plain = Cringe.ANSI.strip(line)

    plain
    |> Cringe.Measure.wrap(width)
    |> Enum.reduce({[], 0, 0}, fn chunk, {lines, byte_offset, visible_offset} ->
      rest = binary_part(plain, byte_offset, byte_size(plain) - byte_offset)
      position = match_position(rest, chunk)
      skipped = binary_part(rest, 0, position)
      chunk_width = Width.visible_length(chunk)
      visible_start = visible_offset + Width.visible_length(skipped)
      next_byte_offset = byte_offset + position + byte_size(chunk)

      {[Cringe.Measure.slice(line, visible_start, chunk_width) | lines], next_byte_offset,
       visible_start + chunk_width}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp match_position(_rest, ""), do: 0

  defp match_position(rest, chunk) do
    case :binary.match(rest, chunk) do
      {position, _length} -> position
      :nomatch -> 0
    end
  end

  defp ansi?(content), do: String.contains?(content, "\e[")

  defp maybe_fg(content, _theme, nil), do: content
  defp maybe_fg(content, theme, fg_key), do: Theme.fg(theme, fg_key, content)

  defp preserve_background(content, background) do
    content
    |> IO.iodata_to_binary()
    |> String.replace(Theme.reset(), Theme.reset() <> background)
  end
end
