defmodule Exy.Runtime.StandaloneTest do
  use ExUnit.Case, async: false

  test "preserves Livebook-style evaluator context" do
    assert {:ok, runtime} = Exy.Runtime.Standalone.start_link()
    assert {:ok, %{status: :ok, value: 3}} = Exy.Runtime.Standalone.evaluate(runtime, "x = 1 + 2")
    assert {:ok, %{status: :ok, value: 6}} = Exy.Runtime.Standalone.evaluate(runtime, "x * 2")
    assert :ok = Exy.Runtime.Standalone.stop(runtime)
  end

  test "timeout restarts child evaluator so future evals are not stuck" do
    assert {:ok, runtime} = Exy.Runtime.Standalone.start_link()

    assert {:ok, %{status: :timeout}} =
             Exy.Runtime.Standalone.evaluate(runtime, "Process.sleep(5_000)", timeout: 50)

    assert {:ok, %{status: :ok, value: 2}} =
             Exy.Runtime.Standalone.evaluate(runtime, "1 + 1", timeout: 1_000)

    assert :ok = Exy.Runtime.Standalone.stop(runtime)
  end

  test "captures IO away from protocol output" do
    assert {:ok, runtime} = Exy.Runtime.Standalone.start_link()

    assert {:ok, %{status: :ok, output: output, value: :ok}} =
             Exy.Runtime.Standalone.evaluate(runtime, ~s|IO.puts("hello")|)

    assert output =~ "hello"
    assert :ok = Exy.Runtime.Standalone.stop(runtime)
  end
end
