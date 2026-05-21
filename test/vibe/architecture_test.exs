defmodule Vibe.ArchitectureTest do
  use ExUnit.Case, async: true

  test "Jason encoders live only in storage representations" do
    offenders =
      "lib/vibe"
      |> Path.join("**/*.ex")
      |> Path.wildcard()
      |> Enum.reject(&String.starts_with?(&1, "lib/vibe/storage/representation/"))
      |> Enum.filter(fn path ->
        path
        |> File.read!()
        |> String.contains?("defimpl Jason.Encoder")
      end)

    assert offenders == []
  end
end
