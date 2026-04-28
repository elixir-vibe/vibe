defmodule Exy.Runtime.StandaloneTest do
  use ExUnit.Case, async: false

  @blocking_sleep_ms 5_000
  @blocking_eval_code "Process.sleep(#{@blocking_sleep_ms})"
  @post_timeout_eval_ms 1_000

  test "preserves Livebook-style evaluator context" do
    assert {:ok, runtime} = Exy.Runtime.Standalone.start_link()
    assert {:ok, %{status: :ok, value: 3}} = Exy.Runtime.Standalone.evaluate(runtime, "x = 1 + 2")
    assert {:ok, %{status: :ok, value: 6}} = Exy.Runtime.Standalone.evaluate(runtime, "x * 2")
    assert :ok = Exy.Runtime.Standalone.stop(runtime)
  end

  test "timeout restarts child evaluator so future evals are not stuck" do
    assert {:ok, runtime} = Exy.Runtime.Standalone.start_link()

    assert {:ok, %{status: :timeout}} =
             Exy.Runtime.Standalone.evaluate(runtime, @blocking_eval_code, timeout: 50)

    assert {:ok, %{status: :ok, value: 2}} =
             Exy.Runtime.Standalone.evaluate(runtime, "1 + 1", timeout: @post_timeout_eval_ms)

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
