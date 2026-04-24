defmodule Exy.ChecksTest do
  use ExUnit.Case, async: false

  test "analysis gives agent-friendly summary without reruns" do
    report = Exy.Checks.analyze(checks: [:reach])

    assert report.ok?
    assert report.failed == []
    assert [%{name: :reach, status: :ok}] = report.summary
    assert [%{name: :reach, status: :ok, details: %{files: files}}] = report.results
    assert files > 0
  end
end
