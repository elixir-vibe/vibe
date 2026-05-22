defmodule Vibe.TUI.Views.AgentsTest do
  use ExUnit.Case, async: true

  alias Vibe.Terminal.Theme
  alias Vibe.TUI.Views.Agents

  test "new returns a dashboard with sessions" do
    dashboard = Agents.new(width: 80, height: 24)
    assert %Agents{} = dashboard
    assert is_list(dashboard.sessions)
    assert dashboard.selected == 0
    assert dashboard.peek == nil
  end

  test "move navigates within bounds" do
    dashboard = %Agents{sessions: [%{id: "a"}, %{id: "b"}, %{id: "c"}], selected: 0}

    assert %{selected: 1} = Agents.move(dashboard, :down)
    assert %{selected: 0} = Agents.move(dashboard, :up)
    assert %{selected: 2} = dashboard |> Agents.move(:down) |> Agents.move(:down)

    assert %{selected: 2} =
             dashboard |> Agents.move(:down) |> Agents.move(:down) |> Agents.move(:down)
  end

  test "move on empty sessions is safe" do
    dashboard = %Agents{sessions: [], selected: 0}
    assert %{selected: 0} = Agents.move(dashboard, :down)
    assert %{selected: 0} = Agents.move(dashboard, :up)
  end

  test "selected_session returns the highlighted session" do
    sessions = [%{id: "first"}, %{id: "second"}]
    assert %{id: "first"} = Agents.selected_session(%Agents{sessions: sessions, selected: 0})
    assert %{id: "second"} = Agents.selected_session(%Agents{sessions: sessions, selected: 1})
    assert nil == Agents.selected_session(%Agents{sessions: [], selected: 0})
  end

  test "toggle_peek opens and closes the peek panel" do
    sessions = [%{id: "s1", status: :idle, first_message: "hello", model: "test"}]
    dashboard = %Agents{sessions: sessions, selected: 0}

    with_peek = Agents.toggle_peek(dashboard)
    assert with_peek.peek != nil

    without_peek = Agents.toggle_peek(with_peek)
    assert without_peek.peek == nil
  end

  test "render produces lines" do
    sessions = [
      %{
        id: "s1",
        status: :working,
        first_message: "fix bug",
        last_message_preview: "fixing...",
        model: "gpt-5.5"
      },
      %{
        id: "s2",
        status: :idle,
        first_message: "hello",
        last_message_preview: nil,
        model: "claude"
      }
    ]

    dashboard = %Agents{sessions: sessions, selected: 0, width: 80, height: 24}
    lines = Agents.render(dashboard, Theme.default())
    assert [_ | _] = lines

    text = Enum.map_join(lines, "\n", &IO.iodata_to_binary/1)
    assert text =~ "Agent sessions"
    assert text =~ "fix bug"
    assert text =~ "hello"
  end

  test "render with empty sessions shows placeholder" do
    dashboard = %Agents{sessions: [], selected: 0, width: 80, height: 24}
    lines = Agents.render(dashboard, Theme.default())
    text = Enum.map_join(lines, "\n", &IO.iodata_to_binary/1)
    assert text =~ "No sessions"
  end

  test "refresh reloads sessions" do
    dashboard = %Agents{sessions: [%{id: "stale"}], selected: 0, width: 80, height: 24}
    refreshed = Agents.refresh(dashboard)
    assert is_list(refreshed.sessions)
  end
end
