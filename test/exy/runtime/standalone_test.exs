defmodule Exy.Runtime.StandaloneTest do
  use ExUnit.Case, async: false

  test "preserves Livebook-style evaluator context" do
    assert {:ok, runtime} = Exy.Runtime.start_link()
    assert {:ok, %{status: :ok, value: 3}} = Exy.Runtime.evaluate(runtime, "x = 1 + 2")
    assert {:ok, %{status: :ok, value: 6}} = Exy.Runtime.evaluate(runtime, "x * 2")
    assert :ok = Exy.Runtime.stop(runtime)
  end

  test "timeout restarts child evaluator so future evals are not stuck" do
    assert {:ok, runtime} = Exy.Runtime.start_link()

    assert {:ok, %{status: :timeout}} =
             Exy.Runtime.evaluate(runtime, "Process.sleep(5_000)", timeout: 50)

    assert {:ok, %{status: :ok, value: 2}} =
             Exy.Runtime.evaluate(runtime, "1 + 1", timeout: 1_000)

    assert :ok = Exy.Runtime.stop(runtime)
  end

  test "captures IO away from protocol output" do
    assert {:ok, runtime} = Exy.Runtime.start_link()

    assert {:ok, %{status: :ok, output: output, value: :ok}} =
             Exy.Runtime.evaluate(runtime, ~s|IO.puts("hello")|)

    assert output =~ "hello"
    assert :ok = Exy.Runtime.stop(runtime)
  end
end
