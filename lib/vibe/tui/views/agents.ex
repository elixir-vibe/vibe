defmodule Vibe.TUI.Views.Agents do
  @moduledoc """
  TUI agent dashboard view — shows all sessions with status, preview, and dispatch.

  Renders a table of sessions grouped by state, with inline peek preview and
  an input for dispatching new background sessions. Arrow keys navigate rows,
  Space peeks, Enter attaches, and Esc exits back to the attached session.
  """

  alias Vibe.Session.Listing
  alias Vibe.TUI.{Theme, Widget}

  @type t :: %__MODULE__{
          sessions: [map()],
          selected: non_neg_integer(),
          peek: map() | nil,
          width: pos_integer(),
          height: pos_integer()
        }

  defstruct sessions: [],
            selected: 0,
            peek: nil,
            width: 100,
            height: 30

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    sessions = Listing.list()

    %__MODULE__{
      sessions: sessions,
      selected: 0,
      width: Keyword.get(opts, :width, 100),
      height: Keyword.get(opts, :height, 30)
    }
  end

  @spec refresh(t()) :: t()
  def refresh(%__MODULE__{} = state) do
    sessions = Listing.list()
    selected = min(state.selected, max(length(sessions) - 1, 0))
    %{state | sessions: sessions, selected: selected}
  end

  @spec move(t(), :up | :down) :: t()
  def move(%{sessions: []} = state, _direction), do: state

  def move(%{sessions: sessions, selected: selected} = state, :up),
    do: %{state | selected: max(selected - 1, 0), peek: peek_session(sessions, selected - 1)}

  def move(%{sessions: sessions, selected: selected} = state, :down),
    do: %{
      state
      | selected: min(selected + 1, length(sessions) - 1),
        peek: peek_session(sessions, selected + 1)
    }

  @spec selected_session(t()) :: map() | nil
  def selected_session(%{sessions: sessions, selected: selected}),
    do: Enum.at(sessions, selected)

  @spec toggle_peek(t()) :: t()
  def toggle_peek(%{peek: nil} = state) do
    case selected_session(state) do
      nil -> state
      _session -> %{state | peek: peek_data(state)}
    end
  end

  def toggle_peek(state), do: %{state | peek: nil}

  @spec render(t(), Theme.t()) :: [IO.chardata()]
  def render(%__MODULE__{} = state, theme) do
    header = render_header(state, theme)
    rows = render_rows(state, theme)
    peek_lines = if state.peek, do: render_peek(state, theme), else: []
    hint = render_hint(theme)

    header ++ rows ++ peek_lines ++ hint
  end

  defp render_header(state, theme) do
    count = length(state.sessions)
    working = Enum.count(state.sessions, &(Map.get(&1, :status) == :working))
    idle = count - working

    title = Theme.fg(theme, :fg_strong, "Agent sessions")
    stats = Theme.fg(theme, :muted, " #{count} total · #{working} working · #{idle} idle")

    [
      "",
      [Widget.spaces(2), title, stats],
      [Widget.spaces(2), Theme.fg(theme, :dim, String.duplicate("─", min(state.width - 4, 60)))],
      ""
    ]
  end

  defp render_rows(%{sessions: []}, theme) do
    [[Widget.spaces(4), Theme.fg(theme, :dim, "No sessions. Type a prompt below to start one.")]]
  end

  defp render_rows(state, theme) do
    state.sessions
    |> Enum.with_index()
    |> Enum.map(fn {session, index} ->
      render_row(session, index == state.selected, state.width, theme)
    end)
  end

  defp render_row(session, selected?, width, theme) do
    icon = status_icon(session, theme)
    name = session_name(session)
    preview = Map.get(session, :last_message_preview) || Map.get(session, :first_message) || ""
    preview = String.slice(preview, 0, max(width - 40, 20))

    remote_tag = if Map.get(session, :remote?), do: Theme.fg(theme, :dim, " [remote]"), else: []

    line = [
      Widget.spaces(2),
      if(selected?, do: Theme.fg(theme, :accent, "› "), else: "  "),
      icon,
      " ",
      Theme.fg(theme, :fg_strong, String.pad_trailing(String.slice(name, 0, 24), 25)),
      remote_tag,
      Theme.fg(theme, :muted, preview)
    ]

    if selected?,
      do: [IO.ANSI.reset(), Theme.bg(theme, :surface_muted, line), IO.ANSI.reset()],
      else: line
  end

  defp render_peek(%{peek: nil}, _theme), do: []

  defp render_peek(%{peek: peek}, theme) do
    [
      "",
      [Widget.spaces(2), Theme.fg(theme, :dim, String.duplicate("─", 40))],
      [Widget.spaces(2), Theme.fg(theme, :fg_strong, peek.title)],
      [Widget.spaces(4), Theme.fg(theme, :muted, peek.status)],
      "",
      [Widget.spaces(4), Theme.fg(theme, :fg, String.slice(peek.last_message, 0, 200))]
    ]
  end

  defp render_hint(theme) do
    [
      "",
      [
        Widget.spaces(2),
        Theme.fg(theme, :dim, "↑↓ navigate  Space peek  Enter attach  Esc back  → attach")
      ]
    ]
  end

  defp status_icon(session, theme) do
    case Map.get(session, :status) do
      :working -> Theme.fg(theme, :accent, "✽")
      :idle -> Theme.fg(theme, :dim, "∙")
      :error -> Theme.fg(theme, :error, "×")
      _status -> Theme.fg(theme, :success, "✓")
    end
  end

  defp session_name(session) do
    Map.get(session, :first_message) ||
      Map.get(session, :last_message_preview) ||
      session.id
  end

  defp peek_session(sessions, index) do
    case Enum.at(sessions, max(index, 0)) do
      nil -> nil
      _session -> nil
    end
  end

  defp peek_data(state) do
    case selected_session(state) do
      nil ->
        nil

      session ->
        %{
          title: session_name(session),
          status:
            "#{Map.get(session, :status, :idle)} · #{Map.get(session, :model, "")} · #{session.id}",
          last_message:
            Map.get(session, :last_message_preview) || Map.get(session, :first_message) || ""
        }
    end
  end
end
