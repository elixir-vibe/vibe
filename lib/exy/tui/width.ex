defmodule Exy.TUI.Width do
  @moduledoc """
  Width helpers for ANSI-styled terminal lines.
  """

  @spec visible_text(IO.chardata()) :: String.t()
  def visible_text(text) do
    text
    |> IO.iodata_to_binary()
    |> Exy.TUI.Theme.strip()
  end

  @spec visible_length(IO.chardata()) :: non_neg_integer()
  def visible_length(text), do: text |> visible_text() |> String.length()
end
