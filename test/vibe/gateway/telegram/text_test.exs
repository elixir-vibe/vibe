defmodule Vibe.Gateway.Telegram.TextTest do
  use ExUnit.Case, async: true

  alias Vibe.Gateway.Telegram.Text

  test "escapes raw HTML and renders a small markdown subset" do
    html = Text.to_html("**bold** `code` <tag> & *italics*")

    assert html =~ "<b>bold</b>"
    assert html =~ "<code>code</code>"
    assert html =~ "&lt;tag&gt; &amp;"
    assert html =~ "<i>italics</i>"
  end

  test "splits long text below limit" do
    chunks = Text.split(String.duplicate("a", 10) <> " " <> String.duplicate("b", 10), limit: 12)

    assert Enum.all?(chunks, &(String.length(&1) <= 12))
    assert Enum.join(chunks, " ") == String.duplicate("a", 10) <> " " <> String.duplicate("b", 10)
  end
end
