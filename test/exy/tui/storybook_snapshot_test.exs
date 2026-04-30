defmodule Exy.TUI.StorybookSnapshotTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.Storybook

  @snapshot_dir Path.expand("../../fixtures/tui/storybook", __DIR__)
  @plain_stories [:markdown_rich, :input, :plugin_widget, :status_rows]
  @ansi_stories [:markdown_rich, :plugin_widget]
  @tool_visual_stories [
    :tool_eval_preparing,
    :tool_eval_running,
    :tool_eval_expanded,
    :tool_read_markdown,
    :tool_write_created_file,
    :tool_edit_diff,
    :chat_tool_stress
  ]
  @tool_visual_widths [40, 80, 120]

  for story <- @plain_stories do
    @story story
    test "plain storybook snapshot: #{@story}" do
      assert snapshot("#{@story}.plain.txt") == render_plain(@story)
    end
  end

  for story <- @ansi_stories do
    @story story
    test "ansi storybook snapshot: #{@story}" do
      assert snapshot("#{@story}.ansi.txt") == render_ansi(@story)
    end
  end

  for story <- @tool_visual_stories, width <- @tool_visual_widths do
    @story story
    @width width
    test "tool visual snapshot: #{@story} width #{@width}" do
      assert snapshot("#{@story}.w#{@width}.plain.txt") == render_plain(@story, width: @width)
      assert snapshot("#{@story}.w#{@width}.ansi.txt") == render_ansi(@story, width: @width)
    end
  end

  defp snapshot(name), do: File.read!(Path.join(@snapshot_dir, name))

  defp render_plain(story, opts \\ []) do
    story
    |> Storybook.render_plain(width: Keyword.get(opts, :width, 80))
    |> Enum.join("\n")
    |> then(&(&1 <> "\n"))
  end

  defp render_ansi(story, opts \\ []) do
    story
    |> Storybook.render(width: Keyword.get(opts, :width, 80))
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
    |> then(&(&1 <> "\n"))
  end
end
