defmodule Exy.ScriptTest do
  use ExUnit.Case, async: false

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
