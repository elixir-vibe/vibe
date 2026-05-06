defmodule Vibe.TUI.PartialRendererTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{PartialRenderer, RenderState, Theme}
  alias Vibe.UI.Block.{Footer, ToolCall, UserMessage}

  test "reuses unchanged body blocks when picker changes" do
    view = view(body: [message(), tool()], picker: nil)

    %{state: state} = PartialRenderer.render_body(view, 80, Theme.default(), RenderState.new())
    first_stats = RenderState.stats(state)

    view_with_picker = view(body: [message(), tool()], picker: picker("/model"))
    %{state: state} = PartialRenderer.render_body(view_with_picker, 80, Theme.default(), state)
    second_stats = RenderState.stats(state)

    assert second_stats.hits >= first_stats.hits + 3
    assert second_stats.misses == first_stats.misses + 1
  end

  test "invalidates a changed tool block without invalidating unchanged messages" do
    state = RenderState.new()

    %{state: state} =
      PartialRenderer.render_body(
        view(body: [message(), tool(output: "one")]),
        80,
        Theme.default(),
        state
      )

    first_stats = RenderState.stats(state)

    %{state: state} =
      PartialRenderer.render_body(
        view(body: [message(), tool(output: "two")]),
        80,
        Theme.default(),
        state
      )

    second_stats = RenderState.stats(state)

    assert second_stats.hits > first_stats.hits
    assert second_stats.misses == first_stats.misses + 1
  end

  defp view(opts) do
    %{
      body: Keyword.fetch!(opts, :body),
      footer: %Footer{
        cwd: "/tmp",
        model: "model-a",
        effort: :medium,
        session_id: "s1",
        status: :idle
      },
      overlays: [],
      notifications: nil,
      picker: Keyword.get(opts, :picker),
      plugin_widgets: %{above_editor: [], below_editor: [], sidebar: []}
    }
  end

  defp message do
    %UserMessage{id: "m1", text: "hello", at: ~U[2026-01-01 00:00:00Z]}
  end

  defp tool(opts \\ []) do
    %ToolCall{
      id: "tool-1",
      name: :read,
      status: :ok,
      args: %{path: "demo.ex"},
      output: %{
        path: "demo.ex",
        content: Keyword.get(opts, :output, "defmodule Demo do\nend"),
        language: "elixir"
      },
      expanded?: false,
      truncate?: false
    }
  end

  defp picker(query) do
    %{
      type: :autocomplete,
      props: %{
        title: "Commands",
        query: query,
        selected: 0,
        items: [%{value: "/model"}],
        limit: 7
      }
    }
  end
end
