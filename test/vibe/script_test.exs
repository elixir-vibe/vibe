defmodule Vibe.ScriptTest do
  use ExUnit.Case, async: false

  @blocking_sleep_ms 5_000
  @blocking_script "Process.sleep(#{@blocking_sleep_ms})"

  test "standalone errors keep result map shape" do
    result = Vibe.Script.run_string(@blocking_script, runtime: :standalone, timeout: 20)

    assert %{status: :timeout, exit_status: 1, output: output} = result
    assert is_binary(output)
  end

  test "runner supports Mix.install style scripts in another BEAM" do
    result =
      Vibe.Script.run_string(~s'''
      Mix.install([])
      IO.puts("script ok")
      ''')

    assert result.status == :ok
    assert result.output =~ "script ok"
  end
end
