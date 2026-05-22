defmodule Vibe.Presentation.Markdown.FenceTest do
  use ExUnit.Case, async: true

  alias Vibe.Presentation.Markdown.Fence

  test "uses a simple code fence for ordinary text" do
    assert Fence.code_block("text", "hello") |> IO.iodata_to_binary() == "```text\nhello\n```"
  end

  test "uses a longer fence than any backtick run in the body" do
    markdown = Fence.code_block("json", "before ``` after ````") |> IO.iodata_to_binary()

    assert markdown == "`````json\nbefore ``` after ````\n`````"
  end

  test "trims nil and blank bodies" do
    assert Fence.code_block("text", nil) |> IO.iodata_to_binary() == "```text\n\n```"
    assert Fence.code_block("text", "  hello  ") |> IO.iodata_to_binary() == "```text\nhello\n```"
  end
end
