defmodule Vibe.Plugins.WebSearch.Presentation.FetchBodyTest do
  use ExUnit.Case, async: true

  alias Vibe.Plugins.WebSearch.Presentation.FetchBody

  test "markdown format returns raw text" do
    assert FetchBody.markdown(%{format: :markdown, text: "# Title"}) == "# Title"
    assert FetchBody.markdown(%{format: :markdown, text: nil}) == ""
  end

  test "html format converts simple HTML to markdown" do
    markdown =
      FetchBody.markdown(%{
        format: :html,
        text: "<h1>Title</h1><p>Hello <strong>web</strong>.</p>"
      })

    assert markdown =~ "Title"
    assert markdown =~ "web"
  end

  test "json and text formats are safely fenced" do
    assert IO.iodata_to_binary(FetchBody.markdown(%{format: :json, text: ~s({"ok":true})})) =~
             "```json"

    text = IO.iodata_to_binary(FetchBody.markdown(%{text: "before\n```\nafter"}))
    assert text =~ "````text"
    assert text =~ "before\n```\nafter"
    assert String.ends_with?(text, "````")
  end
end
