defmodule Vibe.Eval.SandboxTest do
  use ExUnit.Case, async: true

  alias Vibe.Eval.Sandbox

  test "available? returns true when Dune is installed" do
    assert Sandbox.available?()
  end

  test "evaluates safe expressions" do
    assert {:ok, %{value: 42, inspected: "42"}} = Sandbox.eval("40 + 2")
  end

  test "captures stdio" do
    assert {:ok, %{stdio: "hello\n"}} = Sandbox.eval("IO.puts(\"hello\")")
  end

  test "blocks restricted functions" do
    assert {:error, message} = Sandbox.eval("File.cwd!()")
    assert message =~ "restricted"
  end

  test "blocks System access" do
    assert {:error, message} = Sandbox.eval("System.cmd(\"ls\", [])")
    assert message =~ "restricted"
  end

  test "enforces memory limits" do
    assert {:error, message} = Sandbox.eval("List.duplicate(:x, 10_000_000)")
    assert message =~ "memory"
  end

  test "enforces reduction limits" do
    assert {:error, message} =
             Sandbox.eval("Enum.reduce(1..10_000_000, 0, &(&1 + &2))",
               max_reductions: 10_000
             )

    assert message =~ "reductions"
  end

  test "allows standard library" do
    assert {:ok, %{value: [2, 4, 6]}} = Sandbox.eval("Enum.map([1,2,3], & &1 * 2)")
    assert {:ok, %{value: "HELLO"}} = Sandbox.eval("String.upcase(\"hello\")")
  end

  test "respects timeout" do
    assert {:error, message} = Sandbox.eval("Process.sleep(10_000)", timeout: 100)
    assert message =~ "timeout" or message =~ "restricted"
  end
end
