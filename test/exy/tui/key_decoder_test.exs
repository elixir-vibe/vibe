defmodule Exy.TUI.KeyDecoderTest do
  use ExUnit.Case, async: true

  import Ghostty.Test, only: [key_bytes: 1]

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
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :escape}) == [:cancel]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :c, mods: [:ctrl]}) == [:cancel]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :page_up}) == [:scroll_page_up]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :page_down}) == [:scroll_page_down]
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :u, mods: [:ctrl]}) == [:scroll_page_up]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :d, mods: [:ctrl]}) == [
             :scroll_page_down
           ]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :o, mods: [:ctrl]}) == [
             :toggle_truncation
           ]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :a, utf8: "a"}) == [{:insert, "a"}]
  end

  test "decodes Ghostty-encoded terminal bytes" do
    assert :arrow_left |> key_bytes() |> KeyDecoder.decode() == [:left]
    assert :arrow_right |> key_bytes() |> KeyDecoder.decode() == [:right]
    assert :enter |> key_bytes() |> KeyDecoder.decode() == [:submit]
    assert KeyDecoder.decode("\e\r") == [:enter]

    assert :backspace |> key_bytes() |> KeyDecoder.decode() == [:backspace]
    assert KeyDecoder.decode("\e[5~") == [:scroll_page_up]
    assert KeyDecoder.decode("\e[6~") == [:scroll_page_down]
    assert KeyDecoder.decode(<<15>>) == [:toggle_truncation]
    assert KeyDecoder.decode(<<21>>) == [:scroll_page_up]
    assert KeyDecoder.decode(<<4>>) == [:scroll_page_down]
  end

  test "decodes printable input and paste" do
    assert KeyDecoder.decode("a") == [{:insert, "a"}]
    assert KeyDecoder.decode("hello") == [{:paste, "hello"}]
  end
end
