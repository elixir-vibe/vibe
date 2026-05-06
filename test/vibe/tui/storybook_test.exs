defmodule Vibe.TUI.StorybookTest do
  use ExUnit.Case, async: true

  test "renders every story as plain lines" do
    for story <- Vibe.TUI.Storybook.stories() do
      lines = Vibe.TUI.Storybook.render_plain(story, width: 80)
      assert lines != []
      assert Enum.all?(lines, &is_binary/1)
    end
  end

  test "includes input, theme, and markdown stories" do
    assert :input in Vibe.TUI.Storybook.stories()
    assert :themes in Vibe.TUI.Storybook.stories()
    assert :markdown_rich in Vibe.TUI.Storybook.stories()
    assert :markdown_streaming in Vibe.TUI.Storybook.stories()
  end
end
