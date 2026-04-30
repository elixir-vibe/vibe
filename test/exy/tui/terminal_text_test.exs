defmodule Exy.TUI.TerminalTextTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.TerminalText

  test "keeps SGR colors" do
    assert TerminalText.sanitize(["\e[31m", "red", "\e[0m"]) == "\e[31mred\e[0m"
  end

  test "strips destructive CSI controls" do
    refute TerminalText.sanitize("hello\e[2J\e[Hworld") =~ "\e[2J"
    assert TerminalText.sanitize("hello\e[2J\e[Hworld") == "helloworld"
  end

  test "strips OSC controls" do
    assert TerminalText.sanitize("\e]0;evil title\ahello") == "hello"
    assert TerminalText.sanitize("\e]8;;https://example.com\ahello\e]8;;\a") == "hello"
  end

  test "strips DCS and other string controls" do
    assert TerminalText.sanitize("a\ePprivate\e\\b") == "ab"
  end

  test "normalizes carriage returns and tabs" do
    assert TerminalText.sanitize("tick\rfinal\tend") == "tick\nfinal    end"
  end
end
