defmodule Vibe.Code.ChecksTest do
  use ExUnit.Case, async: false

  test "analysis gives agent-friendly summary without reruns" do
    path =
      Path.join(System.tmp_dir!(), "vibe-reach-good-#{System.unique_integer([:positive])}.ex")

    File.write!(path, "defmodule Good do\n  def ok, do: :ok\nend\n")

    try do
      report = Vibe.Code.Checks.analyze(checks: [:reach], paths: [path])

      assert report.ok?
      assert report.failed == []
      assert [%{name: :reach, status: :ok}] = report.summary

      assert [%{name: :reach, status: :ok, details: %{files: 1, errors: [], project: project}}] =
               report.results

      assert project.modules > 0
      assert is_map(project.otp)
      assert is_map(project.concurrency)
      assert is_list(project.smells)
    after
      File.rm(path)
    end
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
