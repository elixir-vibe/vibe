defmodule Vibe.Terminal.ThemeTest do
  use ExUnit.Case, async: false

  test "provides dark and light themes" do
    assert Vibe.Terminal.Theme.dark().name == "dark"
    assert Vibe.Terminal.Theme.light().name == "light"
    assert Vibe.Terminal.Theme.named("light").name == "light"
  end

  test "auto-detects light and dark terminal backgrounds" do
    with_env(%{"VIBE_THEME" => nil, "COLORFGBG" => "15;0"}, fn ->
      assert Vibe.Terminal.Theme.default().name == "dark"
    end)

    with_env(%{"VIBE_THEME" => nil, "COLORFGBG" => "0;15"}, fn ->
      assert Vibe.Terminal.Theme.default().name == "light"
    end)
  end

  test "VIBE_THEME overrides terminal background detection" do
    with_env(%{"VIBE_THEME" => "light", "COLORFGBG" => "15;0"}, fn ->
      assert Vibe.Terminal.Theme.default().name == "light"
    end)
  end

  test "applies semantic foreground colors with ANSI reset" do
    styled = Vibe.Terminal.Theme.default() |> Vibe.Terminal.Theme.fg(:error, "boom")

    styled = IO.iodata_to_binary(styled)

    assert styled =~ "\e[38;2;204;102;102m"
    assert styled =~ IO.ANSI.reset()
    assert Vibe.Terminal.Theme.strip(styled) == "boom"
  end

  test "applies RGB backgrounds through truecolor ANSI" do
    styled = Vibe.Terminal.Theme.default() |> Vibe.Terminal.Theme.bg(:tool_pending_bg, "tool")

    styled = IO.iodata_to_binary(styled)

    assert styled =~ "\e[48;2;34;36;42m"
    assert Vibe.Terminal.Theme.strip(styled) == "tool"
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
