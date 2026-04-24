defmodule Exy.TUI.KeyDecoderTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.KeyDecoder

  test "decodes editor keys" do
    assert KeyDecoder.decode("\e[D") == [:left]
    assert KeyDecoder.decode("\e[C") == [:right]
    assert KeyDecoder.decode("\r") == [:submit]
    assert KeyDecoder.decode("\n") == [:enter]
    assert KeyDecoder.decode("\u007F") == [:backspace]
  end

  test "decodes printable input and paste" do
    assert KeyDecoder.decode("a") == [{:insert, "a"}]
    assert KeyDecoder.decode("hello") == [{:paste, "hello"}]
  end
end
