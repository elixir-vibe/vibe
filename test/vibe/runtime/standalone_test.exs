defmodule Vibe.Runtime.StandaloneTest do
  use ExUnit.Case, async: false

  @blocking_sleep_ms 5_000
  @blocking_eval_code "Process.sleep(#{@blocking_sleep_ms})"
  @post_timeout_eval_ms 1_000

  setup_all do
    assert {:ok, runtime} = Vibe.Runtime.Standalone.start_link()
    on_exit(fn -> Vibe.Runtime.Standalone.stop(runtime) end)
    {:ok, runtime: runtime}
  end

  test "preserves Livebook-style evaluator context", %{runtime: runtime} do
    assert {:ok, %{status: :ok, value: 3}} =
             Vibe.Runtime.Standalone.evaluate(runtime, "x = 1 + 2")

    assert {:ok, %{status: :ok, value: 6}} = Vibe.Runtime.Standalone.evaluate(runtime, "x * 2")
  end

  test "timeout restarts child evaluator so future evals are not stuck", %{runtime: runtime} do
    assert {:ok, %{status: :timeout}} =
             Vibe.Runtime.Standalone.evaluate(runtime, @blocking_eval_code, timeout: 50)

    assert {:ok, %{status: :ok, value: 2}} =
             Vibe.Runtime.Standalone.evaluate(runtime, "1 + 1", timeout: @post_timeout_eval_ms)
  end

  test "captures IO away from protocol output", %{runtime: runtime} do
    assert {:ok, %{status: :ok, output: output, value: :ok}} =
             Vibe.Runtime.Standalone.evaluate(runtime, ~s|IO.puts("hello")|)

    assert output =~ "hello"
  end
end
