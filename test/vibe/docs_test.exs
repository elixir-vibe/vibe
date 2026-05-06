defmodule Vibe.DocsTest do
  use ExUnit.Case, async: true

  test "lists built-in help topics" do
    topic_names = Enum.map(Vibe.Docs.topics(), & &1.name)

    assert "quickstart" in topic_names
    assert "eval" in topic_names
    assert "troubleshooting" in topic_names
  end

  test "renders topic aliases" do
    assert Vibe.Docs.render("commands") =~ "# Slash commands"
    assert Vibe.Docs.render("session") =~ "# Sessions"
  end

  test "renders unknown topic with index" do
    rendered = Vibe.Docs.render("missing")

    assert rendered =~ "# Unknown help topic"
    assert rendered =~ "vibe help <topic>"
  end
end
