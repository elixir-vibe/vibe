defmodule Exy.ScriptTest do
  use ExUnit.Case, async: false

  test "standalone errors keep result map shape" do
    result = Exy.Script.run_string("Process.sleep(5_000)", runtime: :standalone, timeout: 20)

    assert %{status: :timeout, exit_status: 1, output: output} = result
    assert is_binary(output)
  end

  test "runner supports Mix.install style scripts in another BEAM" do
    result =
      Exy.Script.run_string(~s'''
      Mix.install([])
      IO.puts("script ok")
      ''')

    assert result.status == :ok
    assert result.output =~ "script ok"
  end
end
