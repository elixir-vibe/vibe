defmodule Exy.TUI.StorybookTest do
  use ExUnit.Case, async: true

  test "renders every story as plain lines" do
    for story <- Exy.TUI.Storybook.stories() do
      lines = Exy.TUI.Storybook.render_plain(story, width: 80)
      assert lines != []
      assert Enum.all?(lines, &is_binary/1)
    end
  end
end
