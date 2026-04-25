defmodule Exy.TUI.Width do
  @moduledoc """
  Width helpers for ANSI-styled terminal lines.
  """

  @variation_selector_16 0xFE0F
  @zero_width_joiner 0x200D

  @spec visible_text(IO.chardata()) :: String.t()
  def visible_text(text) do
    text
    |> IO.iodata_to_binary()
    |> Exy.TUI.Theme.strip()
  end

  @spec visible_length(IO.chardata()) :: non_neg_integer()
  def visible_length(text) do
    text
    |> visible_text()
    |> String.graphemes()
    |> Enum.reduce(0, &(&2 + grapheme_width(&1)))
  end

  @spec take(IO.chardata(), non_neg_integer()) :: String.t()
  def take(text, width) do
    text
    |> visible_text()
    |> String.graphemes()
    |> Enum.reduce_while({[], 0}, fn grapheme, {acc, used} ->
      grapheme_width = grapheme_width(grapheme)

      if used + grapheme_width <= width do
        {:cont, {[grapheme | acc], used + grapheme_width}}
      else
        {:halt, {acc, used}}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> Enum.join()
  end

  @spec chunks(IO.chardata(), pos_integer()) :: [String.t()]
  def chunks(text, width) do
    text
    |> visible_text()
    |> String.graphemes()
    |> Enum.reduce({[], [], 0}, fn grapheme, {chunks, current, used} ->
      grapheme_width = grapheme_width(grapheme)

      if used > 0 and used + grapheme_width > width do
        {[current_to_string(current) | chunks], [grapheme], grapheme_width}
      else
        {chunks, [grapheme | current], used + grapheme_width}
      end
    end)
    |> then(fn
      {chunks, [], _used} -> chunks
      {chunks, current, _used} -> [current_to_string(current) | chunks]
    end)
    |> Enum.reverse()
  end

  defp current_to_string(current), do: current |> Enum.reverse() |> Enum.join()

  defp grapheme_width(grapheme) do
    codepoints = String.to_charlist(grapheme)

    cond do
      codepoints == [] -> 0
      Enum.any?(codepoints, &(&1 == @zero_width_joiner)) -> 2
      Enum.any?(codepoints, &(&1 == @variation_selector_16)) -> 2
      Enum.any?(codepoints, &wide_codepoint?/1) -> 2
      Enum.all?(codepoints, &zero_width_codepoint?/1) -> 0
      true -> 1
    end
  end

  defp zero_width_codepoint?(codepoint) do
    codepoint in 0x0300..0x036F or
      codepoint in 0x1AB0..0x1AFF or
      codepoint in 0x1DC0..0x1DFF or
      codepoint in 0x20D0..0x20FF or
      codepoint in 0xFE00..0xFE0F
  end

  defp wide_codepoint?(codepoint) do
    codepoint in 0x1100..0x115F or
      codepoint in 0x2329..0x232A or
      codepoint in 0x2E80..0xA4CF or
      codepoint in 0xAC00..0xD7A3 or
      codepoint in 0xF900..0xFAFF or
      codepoint in 0xFE10..0xFE19 or
      codepoint in 0xFE30..0xFE6F or
      codepoint in 0xFF00..0xFF60 or
      codepoint in 0xFFE0..0xFFE6 or
      codepoint in 0x1F000..0x1FAFF or
      codepoint in 0x2600..0x27BF
  end
end
