defmodule Exy.TUI.KeyDecoder do
  @moduledoc """
  Terminal byte-sequence decoder for editor-level keys.
  """

  @type key :: Exy.UI.Editor.key()

  @spec decode_event(Ghostty.KeyEvent.t()) :: [key()]
  def decode_event(%Ghostty.KeyEvent{key: :arrow_left}), do: [:left]
  def decode_event(%Ghostty.KeyEvent{key: :arrow_right}), do: [:right]
  def decode_event(%Ghostty.KeyEvent{key: :arrow_up}), do: [:up]
  def decode_event(%Ghostty.KeyEvent{key: :arrow_down}), do: [:down]
  def decode_event(%Ghostty.KeyEvent{key: :home}), do: [:home]
  def decode_event(%Ghostty.KeyEvent{key: :end}), do: [:end]
  def decode_event(%Ghostty.KeyEvent{key: :delete}), do: [:delete]
  def decode_event(%Ghostty.KeyEvent{key: :backspace}), do: [:backspace]
  def decode_event(%Ghostty.KeyEvent{key: :enter, mods: [:shift]}), do: [:enter]
  def decode_event(%Ghostty.KeyEvent{key: :enter, mods: [:alt]}), do: [:enter]
  def decode_event(%Ghostty.KeyEvent{key: :enter}), do: [:submit]
  def decode_event(%Ghostty.KeyEvent{key: :tab}), do: [:tab]
  def decode_event(%Ghostty.KeyEvent{key: :escape}), do: [:cancel]
  def decode_event(%Ghostty.KeyEvent{key: :c, mods: [:ctrl]}), do: [:cancel]
  def decode_event(%Ghostty.KeyEvent{key: :o, mods: [:ctrl]}), do: [:toggle_truncation]
  def decode_event(%Ghostty.KeyEvent{key: :b, mods: [:alt]}), do: [:word_left]
  def decode_event(%Ghostty.KeyEvent{key: :f, mods: [:alt]}), do: [:word_right]

  def decode_event(%Ghostty.KeyEvent{utf8: utf8}) when is_binary(utf8) and byte_size(utf8) > 1,
    do: [{:paste, utf8}]

  def decode_event(%Ghostty.KeyEvent{utf8: utf8}) when is_binary(utf8), do: [{:insert, utf8}]
  def decode_event(%Ghostty.KeyEvent{}), do: []

  @spec decode(binary()) :: [key()]
  def decode(""), do: []
  def decode("\e\r"), do: [:enter]
  def decode("\e\n"), do: [:enter]
  def decode(<<15>>), do: [:toggle_truncation]

  def decode(data) when is_binary(data) do
    case Ghostty.KeyDecoder.decode(data) do
      {:key, event} -> decode_event(event)
      {:data, data} -> decode_data(data)
    end
  end

  defp decode_data(data), do: data |> decode_data([], "") |> Enum.reverse()

  defp decode_data("", keys, pending), do: flush_pending(keys, pending)

  defp decode_data(<<char::utf8, rest::binary>>, keys, pending) when char in [?\r, ?\n] do
    keys = [:submit | flush_pending(keys, pending)]
    decode_data(rest, keys, "")
  end

  defp decode_data(<<char::utf8, rest::binary>>, keys, pending) do
    char = <<char::utf8>>

    if printable?(char) do
      decode_data(rest, keys, pending <> char)
    else
      decode_data(rest, keys, pending)
    end
  end

  defp flush_pending(keys, ""), do: keys

  defp flush_pending(keys, pending) do
    if String.length(pending) == 1 do
      [{:insert, pending} | keys]
    else
      [{:paste, pending} | keys]
    end
  end

  defp printable?(data), do: String.printable?(data) and not String.match?(data, ~r/[\p{C}]/u)
end
