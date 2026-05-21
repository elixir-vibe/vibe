defmodule Vibe.Presentation.Markdown.CommandResultTest do
  use ExUnit.Case, async: true

  test "renders command results as Markdown" do
    markdown =
      Vibe.Markdown.to_markdown(%Vibe.Command.Result{
        id: "cmd-1",
        argv: ["echo", "ok"],
        cwd: "/tmp",
        status: :ok,
        exit_status: 0,
        output: "ok\n",
        output_path: "/tmp/cmd.log",
        duration_ms: 10
      })

    assert markdown =~ "echo ok"
    assert markdown =~ "ok"
  end
end
