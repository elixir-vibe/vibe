defmodule Vibe.TUI.FrameRendererTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{Renderer, RenderState, Theme, Width}
  alias Vibe.UI.State

  test "visible frame clips history while keeping editor cursor on screen" do
    frame =
      snapshot(messages: messages(20), height: 8, editor_text: "hello", editor_cursor: 5)
      |> Renderer.render_frame(Theme.default(), RenderState.new())

    assert length(frame.lines) <= 8
    assert {row, column} = frame.cursor
    assert row <= 8
    assert column > 1

    assert frame.lines
           |> Enum.map(&Width.visible_text/1)
           |> Enum.any?(&String.contains?(&1, "Prompt"))
  end

  test "full frame cursor starts after untruncated body" do
    snapshot = snapshot(messages: messages(3), height: 8, editor_text: "hello", editor_cursor: 5)

    visible =
      Renderer.render_frame(snapshot, Theme.default(), RenderState.new(), viewport: :visible)

    full = Renderer.render_frame(snapshot, Theme.default(), RenderState.new(), viewport: :full)

    assert elem(full.cursor, 0) >= elem(visible.cursor, 0)
    assert length(full.lines) >= length(visible.lines)
  end

  test "multiline prompt cursor advances by logical rows" do
    frame =
      snapshot(messages: [], height: 12, editor_text: "hello\nworld", editor_cursor: 11)
      |> Renderer.render_frame(Theme.default(), RenderState.new())

    assert {row, column} = frame.cursor
    assert row >= 4
    assert column >= 3
  end

  test "wrapped prompt cursor advances by visual rows" do
    text = String.duplicate("x", 30)

    frame =
      snapshot(
        messages: [],
        width: 14,
        height: 12,
        editor_text: text,
        editor_cursor: String.length(text)
      )
      |> Renderer.render_frame(Theme.default(), RenderState.new())

    assert {row, _column} = frame.cursor
    assert row > 3
  end

  defp snapshot(opts) do
    %{
      ui: %State{
        session_id: "s1",
        cwd: "/tmp",
        model: "model-a",
        effort: :medium,
        messages: Keyword.get(opts, :messages, []),
        status: :idle,
        plugin_widgets: %{}
      },
      editor: %{
        text: Keyword.get(opts, :editor_text, ""),
        cursor: Keyword.get(opts, :editor_cursor, 0)
      },
      autocomplete: nil,
      width: Keyword.get(opts, :width, 80),
      height: Keyword.get(opts, :height, 24)
    }
  end

  defp messages(count) do
    Enum.map(1..count, fn index ->
      %{role: :assistant, text: "message #{index}", at: ~U[2026-01-01 00:00:00Z]}
    end)
  end
end
