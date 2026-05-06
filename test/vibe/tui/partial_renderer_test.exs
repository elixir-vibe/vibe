defmodule Vibe.TUI.PartialRendererTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.{PartialRenderer, Renderer, RenderState, Theme}
  alias Vibe.UI.Block.{AssistantMessage, Footer, ToolCall, UserMessage}
  alias Vibe.UI.State

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

  test "partial body rendering matches pure chat renderer" do
    view = view(body: [message(), tool()], picker: picker("/model"))

    %{body: partial_lines} =
      PartialRenderer.render_body(view, 80, Theme.default(), RenderState.new())

    assert partial_lines == Renderer.render(view, 80, Theme.default())
  end

  test "returns visible frame with cursor and updated render state" do
    snapshot = snapshot(body: [message()], editor_text: "hello", editor_cursor: 5)

    frame =
      PartialRenderer.render_frame(snapshot, Theme.default(), RenderState.new(), picker: nil)

    assert [_ | _] = frame.lines
    assert {row, column} = frame.cursor
    assert row >= 1
    assert column >= 1
    assert RenderState.stats(frame.state).entries > 0
  end

  test "width and theme changes invalidate cached components" do
    view = view(body: [message(), tool()], picker: picker("/model"))

    %{state: state} = PartialRenderer.render_body(view, 80, Theme.dark(), RenderState.new())
    first_stats = RenderState.stats(state)

    %{state: state} = PartialRenderer.render_body(view, 100, Theme.dark(), state)
    width_stats = RenderState.stats(state)

    assert width_stats.hits == first_stats.hits
    assert width_stats.misses > first_stats.misses

    %{state: state} = PartialRenderer.render_body(view, 100, Theme.light(), state)
    theme_stats = RenderState.stats(state)

    assert theme_stats.hits == width_stats.hits
    assert theme_stats.misses > width_stats.misses
  end

  test "loader phase invalidates only streaming assistant block" do
    body = [assistant_message("stable", "done"), assistant_message("streaming", "")]
    view = view(body: body)

    %{state: state} =
      PartialRenderer.render_body(view, 80, Theme.default(), RenderState.new(), loader_phase: 0)

    first_stats = RenderState.stats(state)

    %{state: state} =
      PartialRenderer.render_body(view, 80, Theme.default(), state, loader_phase: 1)

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

  defp snapshot(opts) do
    ui = %State{
      session_id: "s1",
      cwd: "/tmp",
      model: "model-a",
      effort: :medium,
      messages: Enum.map(Keyword.fetch!(opts, :body), &state_message/1),
      status: :idle,
      plugin_widgets: %{}
    }

    %{
      ui: ui,
      editor: %{
        text: Keyword.get(opts, :editor_text, ""),
        cursor: Keyword.get(opts, :editor_cursor, 0)
      },
      autocomplete: nil,
      width: 80,
      height: 24
    }
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

  defp assistant_message(id, text) do
    %AssistantMessage{id: id, text: text, at: ~U[2026-01-01 00:00:00Z]}
  end

  defp state_message(%UserMessage{} = message),
    do: %{role: :user, text: message.text, at: message.at}

  defp state_message(%ToolCall{} = tool), do: tool |> Map.from_struct() |> Map.put(:role, :tool)

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
