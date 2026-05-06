defmodule Vibe.TUI.KeyDecoderTest do
  use ExUnit.Case, async: true

  import Ghostty.Test, only: [key_bytes: 1]

  alias Vibe.TUI.KeyDecoder

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
    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :v, mods: [:ctrl]}) == [:paste_image]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :p, mods: [:ctrl]}) == [
             :cycle_model_forward
           ]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :p, mods: [:ctrl, :shift]}) == [
             :cycle_model_backward
           ]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :l, mods: [:ctrl]}) == [
             :open_model_selector
           ]

    assert KeyDecoder.decode_event(%Ghostty.KeyEvent{key: :tab, mods: [:shift]}) == [
             :cycle_effort
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
    assert KeyDecoder.decode(<<15>>) == [:toggle_truncation]
  end

  test "decodes printable input and paste" do
    assert KeyDecoder.decode("a") == [{:insert, "a"}]
    assert KeyDecoder.decode("hello") == [{:paste, "hello"}]
  end

  test "decodes pasted prompt followed by carriage return as submit" do
    assert KeyDecoder.decode("hello\r") == [{:paste, "hello"}, :submit]
    assert KeyDecoder.decode("hello\n") == [{:paste, "hello"}, :submit]
  end
end
