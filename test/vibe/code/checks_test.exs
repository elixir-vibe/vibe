defmodule Vibe.Code.ChecksTest do
  use ExUnit.Case, async: false

  test "analysis gives agent-friendly summary without reruns" do
    report = Vibe.Code.Checks.analyze(checks: [:reach])

    assert report.ok?
    assert report.failed == []
    assert [%{name: :reach, status: :ok}] = report.summary

    assert [%{name: :reach, status: :ok, details: %{files: files, errors: [], project: project}}] =
             report.results

    assert files > 0
    assert project.modules > 0
    assert is_map(project.otp)
    assert is_map(project.concurrency)
    assert is_list(project.smells)
  end

  test "ast pattern check scans multiple patterns in one traversal" do
    File.mkdir_p!("tmp")
    path = "tmp/vibe-ast-patterns-#{System.unique_integer([:positive])}.ex"
    File.write!(path, "defmodule Bad do\n  def run(value), do: IO.inspect(value)\nend\n")

    try do
      result =
        Vibe.Code.Checks.run(:ast_patterns,
          ast_paths: [path],
          ast_patterns: %{io_inspect: "IO.inspect(_)"}
        )

      assert result.status == :error
      assert [%{pattern: :io_inspect}] = result.details.matches
    after
      File.rm(path)
    end
  end

  test "reach check fails on files it cannot analyze" do
    path = Path.join(System.tmp_dir!(), "vibe-reach-bad-#{System.unique_integer([:positive])}.ex")
    File.write!(path, "defmodule Broken do\n  def nope(\nend\n")

    try do
      result = Vibe.Code.Checks.run(:reach, paths: [path])
      assert result.status == :error
      assert [%{file: ^path}] = result.details.errors
    after
      File.rm(path)
    end
  end
end
