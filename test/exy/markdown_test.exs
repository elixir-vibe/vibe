defmodule Exy.MarkdownTest do
  use ExUnit.Case, async: true

  alias Exy.Command.Result
  alias Exy.Plugins.WebSearch.Result, as: WebSearchResult

  test "renders command results" do
    markdown =
      Exy.Markdown.to_markdown(%Result{
        id: "cmd-1",
        argv: ["mix", "test"],
        cwd: "/tmp/project",
        status: :ok,
        exit_status: 0,
        output: "1 test, 0 failures\n",
        output_path: "/tmp/project/.exy/commands/cmd-1.log",
        duration_ms: 12
      })

    assert markdown =~ "## Command ok"
    assert markdown =~ "`mix test`"
    assert markdown =~ "1 test, 0 failures"
  end

  test "MD alias is available in eval" do
    assert {:ok, output} =
             Exy.Eval.run(~S|MD.to_markdown(%{ok: true})|, session_id: "md-alias-test")

    assert output =~ "ok: `true`"
  end

  test "renders web search results through protocol" do
    result = %WebSearchResult{
      title: "Elixir",
      url: "https://elixir-lang.org",
      author: "José",
      published_date: "2026-01-01",
      summary: "Elixir summary",
      highlights: ["runs on the BEAM"],
      text: "Full text"
    }

    markdown = Exy.Markdown.to_markdown(result)

    assert markdown =~ "### [Elixir](https://elixir-lang.org)"
    assert markdown =~ "**Author:** José"
    assert markdown =~ "Elixir summary"
    assert markdown =~ "runs on the BEAM"
    assert markdown =~ "```text\nFull text\n```"
  end
end
