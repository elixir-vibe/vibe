defmodule Vibe.Auth.WebToken.FileStoreTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Vibe.Auth.WebToken.FileStore

  test "creates missing token file with private permissions" do
    dir = Path.join(System.tmp_dir!(), "vibe-token-#{System.unique_integer([:positive])}")
    path = Path.join(dir, "web-token")

    try do
      assert FileStore.read_or_create!(path, fn -> "secret-token" end) == "secret-token"
      assert File.read!(path) == "secret-token"
      {:ok, file_info} = :file.read_file_info(String.to_charlist(path))
      assert (elem(file_info, 7) &&& 0o777) == 0o600
    after
      File.rm_rf(dir)
    end
  end

  test "reuses existing token without invoking generator" do
    dir = Path.join(System.tmp_dir!(), "vibe-token-#{System.unique_integer([:positive])}")
    path = Path.join(dir, "web-token")

    try do
      File.mkdir_p!(dir)
      File.write!(path, "existing-token\n")

      assert FileStore.read_or_create!(path, fn -> flunk("generator should not run") end) ==
               "existing-token"
    after
      File.rm_rf(dir)
    end
  end
end
