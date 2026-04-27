defmodule Exy.Dogfood.TUITest do
  use ExUnit.Case, async: false

  test "runs a traced interactive scenario" do
    dir = Path.join(System.tmp_dir!(), "exy-dogfood-test-#{System.unique_integer([:positive])}")

    assert {:ok, [%{status: :pass, trace_dir: trace_dir}]} =
             Exy.Dogfood.TUI.run(scenario: "autocomplete_footer", dir: dir)

    assert File.exists?(Path.join(dir, "report.json"))
    assert File.exists?(Path.join(trace_dir, "trace.jsonl"))
    assert File.exists?(Path.join(trace_dir, "final-frame.txt"))

    File.rm_rf!(dir)
  end
end
