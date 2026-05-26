defmodule Vibe.Terminal.Layout do
  @moduledoc "Terminal text layout helpers."

  alias Vibe.Terminal.{Text, Theme, Width}

  @type line :: IO.chardata()

  @spec wrap(IO.chardata(), pos_integer()) :: [line()]
  def wrap(content, width) do
    content
    |> Text.sanitize()
    |> String.split("\n")
    |> Enum.flat_map(&wrap_line(&1, width))
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
