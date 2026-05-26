defmodule Vibe.Terminal.Width do
  @moduledoc """
  Width helpers for ANSI-styled terminal lines.
  """

  @spec visible_text(IO.chardata()) :: String.t()
  def visible_text(text) do
    text
    |> IO.iodata_to_binary()
    |> Vibe.Terminal.Theme.strip()
  end

  @spec visible_length(IO.chardata()) :: non_neg_integer()
  def visible_length(text) do
    text
    |> visible_text()
    |> Cringe.Measure.width()
  end

  @spec take(IO.chardata(), non_neg_integer()) :: String.t()
  def take(text, width) do
    text
    |> visible_text()
    |> Cringe.Measure.take(width)
  end

  @spec chunks(IO.chardata(), pos_integer()) :: [String.t()]
  def chunks(text, width) do
    text
    |> visible_text()
    |> Cringe.Measure.chunks(width)
  end
end
