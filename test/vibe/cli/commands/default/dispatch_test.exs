defmodule Vibe.CLI.Commands.Default.DispatchTest do
  use ExUnit.Case, async: true

  alias Vibe.CLI.Commands.Default.Dispatch

  test "classifies flags by precedence" do
    assert Dispatch.action([], help: true, version: true) == {:help}
    assert Dispatch.action([], version: true) == {:version}
    assert Dispatch.action([], login: :codex) == {:login, :codex}
    assert Dispatch.action([], web: true) == {:web}
    assert Dispatch.action([], eval: "1 + 1") == {:eval, "1 + 1", 30_000}
    assert Dispatch.action([], eval: "1 + 1", timeout: 100) == {:eval, "1 + 1", 100}
    assert Dispatch.action([], compact: true) == {:compact}
    assert Dispatch.action([], checks: true) == {:checks}
    assert Dispatch.action([], codex_usage: true) == {:codex_usage}
    assert Dispatch.action([], sessions: true) == {:sessions}
  end

  test "classifies prompt and background actions" do
    assert Dispatch.action(["hello", "world"], bg: true) == {:background, "hello world"}
    assert Dispatch.action([], bg: true) == {:attach_default}
    assert Dispatch.action([], print: true) == {:ask, {[], []}}

    assert Dispatch.action(["hello", "@image.png", "world"], []) ==
             {:ask, {["image.png"], ["hello", "world"]}}

    assert Dispatch.action([], []) == {:attach_default}
  end
end
