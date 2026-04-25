defmodule Exy.FileToolsTest do
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

    assert {:ok, result} = Exy.FileTools.read_file(path)
    assert result.content == "IO.puts(:ok)\n"
    assert result.language == "elixir"
    assert result.lines == 1
  end

  test "writes files and returns a diff", %{dir: dir} do
    path = Path.join(dir, "sample.txt")

    assert {:ok, result} = Exy.FileTools.write_file(path, "new\n")
    assert File.read!(path) == "new\n"
    assert result.diff =~ "+1  new"
  end

  test "edits files with exact replacements and returns a diff", %{dir: dir} do
    path = Path.join(dir, "sample.txt")
    File.write!(path, "one\ntwo\nthree\n")

    assert {:ok, result} =
             Exy.FileTools.edit_file(path, [%{"oldText" => "two", "newText" => "TWO"}])

    assert File.read!(path) == "one\nTWO\nthree\n"
    assert result.replacements == 1
    assert result.diff =~ "-2  two"
    assert result.diff =~ "+2  TWO"
  end

  test "rejects duplicate exact edit matches", %{dir: dir} do
    path = Path.join(dir, "sample.txt")
    File.write!(path, "same\nsame\n")

    assert {:error, error} =
             Exy.FileTools.edit_file(path, [%{"oldText" => "same", "newText" => "other"}])

    assert error =~ "must be unique"
  end
end
