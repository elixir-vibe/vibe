defmodule Vibe.TUI.KeymapTest do
  use ExUnit.Case, async: true

  import Ghostty.Test, only: [key_bytes: 1]

  alias Vibe.TUI.Keymap

  test "decodes Ghostty key events" do
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :arrow_left}) == [:left]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :arrow_right}) == [:right]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :b, mods: [:alt]}) == [:word_left]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :f, mods: [:alt]}) == [:word_right]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :enter}) == [:submit]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :enter, mods: [:shift]}) == [:enter]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :enter, mods: [:alt]}) == [:enter]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :backspace}) == [:backspace]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :escape}) == [:cancel]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :c, mods: [:ctrl]}) == [:cancel]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :v, mods: [:ctrl]}) == [:paste_image]
    assert Keymap.from_event(%Ghostty.KeyEvent{key: :w, mods: [:ctrl]}) == [:delete_word_left]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :p, mods: [:ctrl]}) == [
             :cycle_model_forward
           ]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :p, mods: [:ctrl, :shift]}) == [
             :cycle_model_backward
           ]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :p, mods: [:shift, :ctrl]}) == [
             :cycle_model_backward
           ]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :l, mods: [:ctrl]}) == [
             :open_model_selector
           ]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :tab, mods: [:shift]}) == [
             :cycle_effort
           ]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :o, mods: [:ctrl]}) == [
             :toggle_truncation
           ]

    assert Keymap.from_event(%Ghostty.KeyEvent{key: :a, utf8: "a"}) == [{:insert, "a"}]
  end

  test "decodes Ghostty-encoded terminal bytes" do
    assert :arrow_left |> key_bytes() |> Keymap.from_bytes() == [:left]
    assert :arrow_right |> key_bytes() |> Keymap.from_bytes() == [:right]
    assert :enter |> key_bytes() |> Keymap.from_bytes() == [:submit]
    assert Keymap.from_bytes("\e\r") == [:enter]

    assert :backspace |> key_bytes() |> Keymap.from_bytes() == [:backspace]
    assert Keymap.from_bytes(<<12>>) == [:open_model_selector]
    assert Keymap.from_bytes(<<15>>) == [:toggle_truncation]
    assert Keymap.from_bytes(<<16>>) == [:cycle_model_forward]
    assert Keymap.from_bytes(<<23>>) == [:delete_word_left]
    assert Keymap.from_bytes("\e[Z") == [:cycle_effort]
  end

  test "decodes printable input and paste" do
    assert Keymap.from_bytes("a") == [{:insert, "a"}]
    assert Keymap.from_bytes("hello") == [{:paste, "hello"}]
  end

  test "decodes pasted prompt followed by carriage return as submit" do
    assert Keymap.from_bytes("hello\r") == [{:paste, "hello"}, :submit]
    assert Keymap.from_bytes("hello\n") == [{:paste, "hello"}, :submit]
  end
end
