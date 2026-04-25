defmodule Exy.TUI.ThemeTest do
  use ExUnit.Case, async: false

  test "provides dark and light themes" do
    assert Exy.TUI.Theme.dark().name == "dark"
    assert Exy.TUI.Theme.light().name == "light"
    assert Exy.TUI.Theme.named("light").name == "light"
  end

  test "auto-detects light and dark terminal backgrounds" do
    with_env(%{"EXY_THEME" => nil, "COLORFGBG" => "15;0"}, fn ->
      assert Exy.TUI.Theme.default().name == "dark"
    end)

    with_env(%{"EXY_THEME" => nil, "COLORFGBG" => "0;15"}, fn ->
      assert Exy.TUI.Theme.default().name == "light"
    end)
  end

  test "EXY_THEME overrides terminal background detection" do
    with_env(%{"EXY_THEME" => "light", "COLORFGBG" => "15;0"}, fn ->
      assert Exy.TUI.Theme.default().name == "light"
    end)
  end

  test "applies semantic foreground colors with ANSI reset" do
    styled = Exy.TUI.Theme.default() |> Exy.TUI.Theme.fg(:error, "boom")

    styled = IO.iodata_to_binary(styled)

    assert styled =~ IO.ANSI.red()
    assert styled =~ IO.ANSI.reset()
    assert Exy.TUI.Theme.strip(styled) == "boom"
  end

  test "applies RGB backgrounds through IO.ANSI color cube" do
    styled = Exy.TUI.Theme.default() |> Exy.TUI.Theme.bg(:tool_pending_bg, "tool")

    styled = IO.iodata_to_binary(styled)

    assert styled =~ IO.ANSI.color_background(1, 1, 1)
    assert Exy.TUI.Theme.strip(styled) == "tool"
  end

  defp with_env(env, fun) do
    previous = Map.new(env, fn {key, _value} -> {key, System.get_env(key)} end)

    try do
      Enum.each(env, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)

      fun.()
    after
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end
  end
end
