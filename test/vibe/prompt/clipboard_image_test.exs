defmodule Vibe.Prompt.ClipboardImageTest do
  use ExUnit.Case, async: false

  test "reports missing pngpaste dependency" do
    path = System.get_env("PATH")
    System.put_env("PATH", "")

    on_exit(fn ->
      if path, do: System.put_env("PATH", path), else: System.delete_env("PATH")
    end)

    assert Vibe.Prompt.ClipboardImage.save(session_id: "clip-test") ==
             {:error, :pngpaste_not_found}
  end
end
