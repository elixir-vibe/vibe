defmodule Exy.DocsTest do
  use ExUnit.Case, async: true

  test "lists built-in help topics" do
    topic_names = Enum.map(Exy.Docs.topics(), & &1.name)

    assert "quickstart" in topic_names
    assert "eval" in topic_names
    assert "troubleshooting" in topic_names
  end

  test "renders topic aliases" do
    assert Exy.Docs.render("commands") =~ "# Slash commands"
    assert Exy.Docs.render("session") =~ "# Sessions"
  end

  test "renders unknown topic with index" do
    rendered = Exy.Docs.render("missing")

    assert rendered =~ "# Unknown help topic"
    assert rendered =~ "exy help <topic>"
  end
end
