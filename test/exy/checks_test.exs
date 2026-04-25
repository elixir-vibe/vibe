defmodule Exy.ChecksTest do
  use ExUnit.Case, async: false

  test "analysis gives agent-friendly summary without reruns" do
    report = Exy.Checks.analyze(checks: [:reach])

    assert report.ok?
    assert report.failed == []
    assert [%{name: :reach, status: :ok}] = report.summary
    assert [%{name: :reach, status: :ok, details: %{files: files, errors: []}}] = report.results
    assert files > 0
  end

  test "reach check fails on files it cannot analyze" do
    path = Path.join(System.tmp_dir!(), "exy-reach-bad-#{System.unique_integer([:positive])}.ex")
    File.write!(path, "defmodule Broken do\n  def nope(\nend\n")

    try do
      result = Exy.Checks.run(:reach, paths: [path])
      assert result.status == :error
      assert [%{file: ^path}] = result.details.errors
    after
      File.rm(path)
    end
  end
end
