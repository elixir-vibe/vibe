defmodule Exy.FilesTest do
  use ExUnit.Case, async: true

  @tmp Path.join(System.tmp_dir!(), "exy-file-tools-test")

  setup do
    dir = Path.join(@tmp, Integer.to_string(System.unique_integer([:positive])))
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    {:ok, dir: dir}
  end

  test "reads files with metadata", %{dir: dir} do
    path = Path.join(dir, "sample.ex")
    File.write!(path, "IO.puts(:ok)\n")

    assert {:ok, result} = Exy.Files.read_file("sample.ex", root: dir)
    assert result.content == "IO.puts(:ok)\n"
    assert result.language == "elixir"
    assert result.lines == 1
  end

  test "writes files and returns a diff", %{dir: dir} do
    path = Path.join(dir, "sample.txt")

    assert {:ok, result} = Exy.Files.write_file("sample.txt", "new\n", root: dir)
    assert File.read!(path) == "new\n"
    assert result.change.diff =~ "+1  new"
  end

  test "edits files with exact replacements and returns a diff", %{dir: dir} do
    path = Path.join(dir, "sample.txt")
    File.write!(path, "one\ntwo\nthree\n")

    assert {:ok, result} =
             Exy.Files.edit_file("sample.txt", [%{"oldText" => "two", "newText" => "TWO"}],
               root: dir
             )

    assert File.read!(path) == "one\nTWO\nthree\n"
    assert result.replacements == 1
    assert result.change.diff =~ "-2  two"
    assert result.change.diff =~ "+2  TWO"
  end

  test "rejects symlinks that resolve outside the workspace", %{dir: dir} do
    outside = Path.join(System.tmp_dir!(), "exy-outside-#{System.unique_integer([:positive])}")
    File.mkdir_p!(outside)
    File.write!(Path.join(outside, "secret.txt"), "secret")
    File.ln_s!(outside, Path.join(dir, "link"))

    try do
      assert {:error, error} = Exy.Files.read_file("link/secret.txt", root: dir)
      assert error =~ "resolves outside workspace"
    after
      File.rm_rf(outside)
    end
  end

  test "rejects paths that escape the workspace", %{dir: dir} do
    assert {:error, error} = Exy.Files.read_file("../outside.txt", root: dir)
    assert error =~ "escapes workspace"

    assert {:error, error} =
             Exy.Files.write_file(Path.join(dir, "absolute.txt"), "x", root: dir)

    assert error =~ "absolute paths are not allowed"
  end

  test "rejects duplicate exact edit matches", %{dir: dir} do
    path = Path.join(dir, "sample.txt")
    File.write!(path, "same\nsame\n")

    assert {:error, error} =
             Exy.Files.edit_file("sample.txt", [%{"oldText" => "same", "newText" => "other"}],
               root: dir
             )

    assert error =~ "must be unique"
  end
end
