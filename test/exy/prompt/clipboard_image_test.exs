defmodule Exy.Prompt.ClipboardImageTest do
  use ExUnit.Case, async: true

  test "reports missing pngpaste dependency" do
    path = System.get_env("PATH")
    System.put_env("PATH", "")

    on_exit(fn ->
      if path, do: System.put_env("PATH", path), else: System.delete_env("PATH")
    end)

    assert Exy.Prompt.ClipboardImage.save(session_id: "clip-test") ==
             {:error, :pngpaste_not_found}
  end
end
