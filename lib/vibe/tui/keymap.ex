defmodule Vibe.TUI.Keymap do
  @moduledoc "Maps Ghostty keyboard events and fallback terminal bytes to Vibe editor actions."

  @type key :: Vibe.UI.Editor.key()

  @spec from_event(Ghostty.KeyEvent.t()) :: [key()]
  def from_event(%Ghostty.KeyEvent{key: :arrow_left}), do: [:left]
  def from_event(%Ghostty.KeyEvent{key: :arrow_right}), do: [:right]
  def from_event(%Ghostty.KeyEvent{key: :arrow_up}), do: [:up]
  def from_event(%Ghostty.KeyEvent{key: :arrow_down}), do: [:down]
  def from_event(%Ghostty.KeyEvent{key: :home}), do: [:home]
  def from_event(%Ghostty.KeyEvent{key: :end}), do: [:end]
  def from_event(%Ghostty.KeyEvent{key: :delete}), do: [:delete]
  def from_event(%Ghostty.KeyEvent{key: :backspace}), do: [:backspace]

  def from_event(%Ghostty.KeyEvent{key: :enter, mods: mods}) do
    if has_any_mod?(mods, [:shift, :alt]), do: [:enter], else: [:submit]
  end

  def from_event(%Ghostty.KeyEvent{key: :tab, mods: mods}) do
    if has_mod?(mods, :shift), do: [:cycle_effort], else: [:tab]
  end

  def from_event(%Ghostty.KeyEvent{key: :escape}), do: [:cancel]

  def from_event(%Ghostty.KeyEvent{key: :c, mods: mods} = event),
    do: if_mod(mods, :ctrl, [:cancel], printable_event(event))

  def from_event(%Ghostty.KeyEvent{key: :v, mods: mods} = event),
    do: if_mod(mods, :ctrl, [:paste_image], printable_event(event))

  def from_event(%Ghostty.KeyEvent{key: :o, mods: mods} = event),
    do: if_mod(mods, :ctrl, [:toggle_truncation], printable_event(event))

  def from_event(%Ghostty.KeyEvent{key: :p, mods: mods} = event) do
    cond do
      has_mod?(mods, :ctrl) and has_mod?(mods, :shift) -> [:cycle_model_backward]
      has_mod?(mods, :ctrl) -> [:cycle_model_forward]
      true -> printable_event(event)
    end
  end

  def from_event(%Ghostty.KeyEvent{key: :l, mods: mods} = event),
    do: if_mod(mods, :ctrl, [:open_model_selector], printable_event(event))

  def from_event(%Ghostty.KeyEvent{key: :b, mods: mods} = event),
    do: if_mod(mods, :alt, [:word_left], printable_event(event))

  def from_event(%Ghostty.KeyEvent{key: :f, mods: mods} = event),
    do: if_mod(mods, :alt, [:word_right], printable_event(event))

  def from_event(%Ghostty.KeyEvent{utf8: utf8}) when is_binary(utf8) and byte_size(utf8) > 1,
    do: [{:paste, utf8}]

  def from_event(%Ghostty.KeyEvent{utf8: utf8}) when is_binary(utf8), do: [{:insert, utf8}]
  def from_event(%Ghostty.KeyEvent{}), do: []

  @spec from_bytes(binary()) :: [key()]
  def from_bytes(""), do: []
  def from_bytes("\e\r"), do: [:enter]
  def from_bytes("\e\n"), do: [:enter]
  def from_bytes("\e[Z"), do: [:cycle_effort]
  def from_bytes(<<12>>), do: [:open_model_selector]
  def from_bytes(<<15>>), do: [:toggle_truncation]
  def from_bytes(<<16>>), do: [:cycle_model_forward]
  def from_bytes(<<22>>), do: [:paste_image]

  def from_bytes(data) when is_binary(data) do
    case Ghostty.KeyDecoder.decode(data) do
      {:key, event} -> from_event(event)
      {:data, data} -> decode_data(data)
    end
  end

  defp if_mod(mods, mod, keys, fallback), do: if(has_mod?(mods, mod), do: keys, else: fallback)

  defp printable_event(%Ghostty.KeyEvent{utf8: utf8})
       when is_binary(utf8) and byte_size(utf8) > 1,
       do: [{:paste, utf8}]

  defp printable_event(%Ghostty.KeyEvent{utf8: utf8}) when is_binary(utf8), do: [{:insert, utf8}]
  defp printable_event(%Ghostty.KeyEvent{}), do: []

  defp has_any_mod?(mods, candidates), do: Enum.any?(candidates, &has_mod?(mods, &1))
  defp has_mod?(mods, mod), do: mod in List.wrap(mods)

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
