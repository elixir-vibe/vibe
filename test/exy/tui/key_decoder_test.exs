defmodule Exy.TUI.KeyDecoderTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.KeyDecoder

  test "decodes Ghostty key events" do
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :arrow_left}) == [:left]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :arrow_right}) == [:right]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :b, mods: [:alt]}) == [:word_left]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :f, mods: [:alt]}) == [:word_right]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :enter}) == [:submit]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :enter, mods: [:shift]}) == [:enter]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :enter, mods: [:alt]}) == [:enter]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :backspace}) == [:backspace]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :a, utf8: "a"}) == [{:insert, "a"}]
  end

  test "decodes Ghostty-encoded terminal bytes" do
    assert ghostty_bytes(%Ghostty.KeyEvent{key: :arrow_left}) |> KeyDecoder.decode() == [:left]
    assert ghostty_bytes(%Ghostty.KeyEvent{key: :arrow_right}) |> KeyDecoder.decode() == [:right]
    assert ghostty_bytes(%Ghostty.KeyEvent{key: :enter}) |> KeyDecoder.decode() == [:submit]
    assert KeyDecoder.decode("\e\r") == [:enter]

    assert ghostty_bytes(%Ghostty.KeyEvent{key: :backspace}) |> KeyDecoder.decode() == [
             :backspace
           ]
  end

  test "decodes printable input and paste" do
    assert KeyDecoder.decode("a") == [{:insert, "a"}]
    assert KeyDecoder.decode("hello") == [{:paste, "hello"}]
  end

  defp ghostty_bytes(event) do
    {:ok, terminal} = Ghostty.Terminal.start_link()
    {:ok, bytes} = Ghostty.Terminal.input_key(terminal, event)
    bytes
  end
end
