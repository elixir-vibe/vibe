defmodule Vibe.TUI.Runtime do
  @moduledoc """
  Startable terminal runtime for Vibe's interactive TUI.
  """

  alias IO.ANSI
  alias Phoenix.PubSub, as: PS
  alias Vibe.Session
  alias Vibe.TUI.{Cast, RuntimeSupervisor, TerminalLoop, TerminalPainter}
  alias Vibe.TUI.Cast.Writer
  alias Vibe.TUI.Views.Agents, as: AgentsView
  alias Vibe.Event

  @interrupt_repeat_window_ms 1_500

  @spec run(keyword()) :: :ok | {:error, term()}
  def run(opts \\ []) do
    {columns, rows} = Ghostty.TTY.size()

    opts =
      opts
      |> Keyword.put_new(:width, columns)
      |> Keyword.put_new(:height, rows)
      |> Keyword.put(:output, false)
      |> Keyword.put(:event_target, self())

    runtime_id = make_ref()
    opts = Keyword.put(opts, :runtime_id, runtime_id)

    with :ok <- ensure_interactive_terminal(),
         {:ok, supervisor} <- RuntimeSupervisor.start_link(opts) do
      run_with_tty(supervisor, runtime_id, columns, rows, opts)
    end
  end

  defp run_with_tty(supervisor, runtime_id, columns, rows, opts) do
    case Ghostty.TTY.start_link(owner: self(), takeover: true) do
      {:ok, tty} ->
        loop = RuntimeSupervisor.name(runtime_id, TerminalLoop)
        cast = start_cast(opts, columns, rows)

        try do
          Process.put(:vibe_runtime_id, runtime_id)
          set_window_title("Vibe")
          painter = render(loop, TerminalPainter.new(columns, rows), cast)
          receive_events(tty, loop, nil, painter, cast)
        after
          restore_window_title()
          write_output(TerminalPainter.cleanup(), cast)
          Writer.close(cast)
          GenServer.stop(tty)
          Supervisor.stop(supervisor)
        end

      {:error, reason} ->
        Supervisor.stop(supervisor)
        {:error, reason}
    end
  end

  defp receive_events(tty, loop, last_interrupt_at, painter, cast) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}} ->
        handle_interrupt(tty, loop, event, last_interrupt_at, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}} ->
        Writer.key(cast, event)
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, last_interrupt_at, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{} = event}} ->
        Writer.key(cast, event)
        TerminalLoop.input_key(loop, event)
        repaint_or_stop(tty, loop, nil, painter, cast)

      {Ghostty.TTY, ^tty, {:data, data}} when is_binary(data) ->
        record_input(cast, data)
        TerminalLoop.input(loop, data)
        repaint_or_stop(tty, loop, nil, painter, cast)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        Writer.resize(cast, columns, rows)
        {painter, _changed?} = resize_painter(loop, painter, {columns, rows})
        repaint_or_stop(tty, loop, nil, painter, cast)

      {TerminalLoop, :event, %{type: :session_backgrounded}} ->
        agents_view(tty, loop, painter, cast)

      {TerminalLoop, :event, %{type: type} = event}
      when type in [
             :model_selected,
             :status_changed,
             :assistant_stream_started,
             :assistant_stream_finished,
             :user_message_added,
             :assistant_message_added
           ] ->
        Writer.app_event(cast, event)
        update_title_from_event(event)
        emit_osc133(event)
        repaint_or_stop(tty, loop, last_interrupt_at, painter, cast)

      {TerminalLoop, :event, event} ->
        Writer.app_event(cast, event)
        repaint_or_stop(tty, loop, last_interrupt_at, painter, cast)

      {Ghostty.TTY, ^tty, :eof} ->
        :ok
    end
  end

  defp repaint_or_stop(tty, loop, last_interrupt_at, painter, cast) do
    case drain_pending_events(tty, loop, last_interrupt_at, painter, cast) do
      {:continue, painter} ->
        painter = render(loop, painter, cast)
        receive_events(tty, loop, last_interrupt_at, painter, cast)

      :stop ->
        :ok

      {:agents, painter} ->
        agents_view(tty, loop, painter, cast)
    end
  end

  defp handle_interrupt(tty, loop, event, last_interrupt_at, painter, cast) do
    now = System.monotonic_time(:millisecond)

    if recent_interrupt?(last_interrupt_at, now) do
      :ok
    else
      Writer.key(cast, event)
      TerminalLoop.input_key(loop, event)
      repaint_or_stop(tty, loop, now, painter, cast)
    end
  end

  defp recent_interrupt?(last_interrupt_at, now \\ System.monotonic_time(:millisecond))
  defp recent_interrupt?(nil, _now), do: false

  defp recent_interrupt?(last_interrupt_at, now),
    do: now - last_interrupt_at <= @interrupt_repeat_window_ms

  defp drain_pending_events(tty, loop, last_interrupt_at, painter, cast) do
    context = {tty, loop, cast, System.monotonic_time(:millisecond) + 8}

    state = %{last_interrupt_at: last_interrupt_at, painter: painter, drained: 0}
    drain_pending_events(context, state)
  end

  defp drain_pending_events(context, state) do
    if pending_drain_finished?(context, state) do
      {:continue, state.painter}
    else
      receive do
        message ->
          message
          |> handle_pending_message(context, state)
          |> continue_pending_drain(context)
      after
        0 -> {:continue, state.painter}
      end
    end
  end

  defp pending_drain_finished?({_tty, _loop, _cast, deadline}, %{drained: drained}) do
    drained >= 25 or System.monotonic_time(:millisecond) >= deadline
  end

  defp handle_pending_message(
         {Ghostty.TTY, tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]} = event}},
         {tty, loop, cast, _deadline},
         %{last_interrupt_at: last_interrupt_at} = state
       ) do
    if recent_interrupt?(last_interrupt_at) do
      :stop
    else
      Writer.key(cast, event)
      TerminalLoop.input_key(loop, event)

      {:continue,
       %{state | last_interrupt_at: System.monotonic_time(:millisecond)} |> bump_drained()}
    end
  end

  defp handle_pending_message(
         {Ghostty.TTY, tty, {:key, %Ghostty.KeyEvent{key: :escape} = event}},
         {tty, loop, cast, _deadline},
         state
       ) do
    Writer.key(cast, event)
    TerminalLoop.input_key(loop, event)
    {:continue, bump_drained(state)}
  end

  defp handle_pending_message(
         {Ghostty.TTY, tty, {:key, %Ghostty.KeyEvent{} = event}},
         {tty, loop, cast, _deadline},
         state
       ) do
    Writer.key(cast, event)
    TerminalLoop.input_key(loop, event)
    {:continue, state |> reset_interrupt() |> bump_drained()}
  end

  defp handle_pending_message(
         {Ghostty.TTY, tty, {:data, data}},
         {tty, loop, cast, _deadline},
         state
       )
       when is_binary(data) do
    record_input(cast, data)
    TerminalLoop.input(loop, data)
    {:continue, state |> reset_interrupt() |> bump_drained()}
  end

  defp handle_pending_message(
         {Ghostty.TTY, tty, {:resize, columns, rows}},
         {tty, loop, cast, _deadline},
         state
       ) do
    Writer.resize(cast, columns, rows)
    {painter, _changed?} = resize_painter(loop, state.painter, {columns, rows})
    {:continue, state |> Map.put(:painter, painter) |> reset_interrupt() |> bump_drained()}
  end

  defp handle_pending_message(
         {TerminalLoop, :event, %{type: :session_backgrounded}},
         _context,
         state
       ) do
    {:agents, state.painter}
  end

  defp handle_pending_message(
         {TerminalLoop, :event, event},
         {_tty, _loop, cast, _deadline},
         state
       ) do
    Writer.app_event(cast, event)
    {:continue, bump_drained(state)}
  end

  defp handle_pending_message({Ghostty.TTY, tty, :eof}, {tty, _loop, _cast, _deadline}, _state),
    do: :stop

  defp handle_pending_message(_message, _context, state), do: {:continue, bump_drained(state)}

  defp continue_pending_drain({:continue, state}, context),
    do: drain_pending_events(context, state)

  defp continue_pending_drain(:stop, _context), do: :stop
  defp continue_pending_drain({:agents, painter}, _context), do: {:agents, painter}

  defp reset_interrupt(state), do: %{state | last_interrupt_at: nil}
  defp bump_drained(state), do: %{state | drained: state.drained + 1}

  @doc """
  Resizes the terminal loop and painter when the terminal dimensions change.
  """
  def resize_painter(
        _loop,
        %TerminalPainter{width: columns, height: rows} = painter,
        {columns, rows}
      ),
      do: {painter, false}

  def resize_painter(loop, %TerminalPainter{} = painter, {columns, rows}) do
    TerminalLoop.resize(loop, columns, rows)
    {TerminalPainter.resize(painter, columns, rows), true}
  end

  defp render(loop, painter, cast) do
    frame = TerminalLoop.render_frame(loop, render_viewport(painter))
    {output, painter} = TerminalPainter.render(painter, frame.lines, frame.cursor)
    write_output(output, cast)
    painter
  end

  defp render_viewport(%TerminalPainter{lines: []}), do: :full
  defp render_viewport(%TerminalPainter{}), do: :visible

  @doc "Builds a complete synchronized terminal repaint frame."
  @spec render_frame([IO.chardata()], {pos_integer(), pos_integer()}, pos_integer()) ::
          IO.chardata()
  def render_frame(lines, cursor, start_row \\ 1) do
    render_chunks(lines, cursor, start_row)
  end

  @doc "Builds ordered repaint chunks used by `render_frame/2` and regression tests."
  @spec render_chunks([IO.chardata()], {pos_integer(), pos_integer()}, pos_integer()) :: [
          IO.chardata()
        ]
  def render_chunks(lines, {cursor_row, cursor_column}, start_row \\ 1) do
    start = [
      begin_synchronized_update(),
      hide_cursor(),
      disable_autowrap(),
      ANSI.home(),
      ANSI.clear()
    ]

    rows =
      lines
      |> Enum.with_index(start_row)
      |> Enum.map(fn {line, row} -> [ANSI.cursor(row, 1), ANSI.clear_line(), line] end)

    finish = [
      end_synchronized_update(),
      ANSI.cursor(cursor_row, cursor_column),
      enable_autowrap(),
      show_cursor()
    ]

    [start | rows] |> Vibe.Terminal.Lines.append(finish)
  end

  defp start_cast(opts, columns, rows) do
    opts =
      opts
      |> Keyword.put(:width, columns)
      |> Keyword.put(:height, rows)

    case Cast.start_writer(opts) do
      {:ok, cast} -> cast
      {:error, _reason} -> nil
    end
  end

  defp record_input(nil, _data), do: :ok

  defp record_input(cast, data) do
    case input_recording(data) do
      {:raw, data} -> Writer.input(cast, data)
      {:redacted, bytes} -> Writer.input_redacted(cast, bytes)
    end
  end

  defp input_recording(data) do
    if raw_input_recording?(), do: {:raw, data}, else: {:redacted, byte_size(data)}
  end

  defp raw_input_recording?, do: System.get_env("VIBE_TUI_CAST_INPUT") == "1"

  defp hide_cursor, do: "\e[?25l"
  defp show_cursor, do: "\e[?25h"
  defp disable_autowrap, do: "\e[?7l"
  defp enable_autowrap, do: "\e[?7h"
  defp begin_synchronized_update, do: "\e[?2026h"
  defp end_synchronized_update, do: "\e[?2026l"

  defp write_output(data, cast) do
    Writer.output(cast, data)
    IO.write(:stdio, data)
  end

  defp agents_view(tty, loop, painter, cast) do
    PS.subscribe(Vibe.PubSub, Session.sessions_topic())
    dashboard = AgentsView.new(width: painter.width, height: painter.height)
    theme = Vibe.Terminal.Theme.default()
    painter = render_agents(dashboard, theme, painter, cast)
    agents_receive(tty, loop, dashboard, theme, painter, cast)
  end

  defp agents_receive(tty, loop, dashboard, theme, painter, cast) do
    receive do
      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :escape}}} ->
        PS.unsubscribe(Vibe.PubSub, Session.sessions_topic())
        painter = TerminalPainter.force_full_redraw(painter)
        painter = render(loop, painter, cast)
        receive_events(tty, loop, nil, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :arrow_right}}} ->
        agents_attach(tty, loop, dashboard, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :enter}}} ->
        agents_attach(tty, loop, dashboard, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :arrow_up}}} ->
        dashboard = AgentsView.move(dashboard, :up)
        painter = render_agents(dashboard, theme, painter, cast)
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :arrow_down}}} ->
        dashboard = AgentsView.move(dashboard, :down)
        painter = render_agents(dashboard, theme, painter, cast)
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :space}}} ->
        dashboard = AgentsView.toggle_peek(dashboard)
        painter = render_agents(dashboard, theme, painter, cast)
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {Ghostty.TTY, ^tty, {:resize, columns, rows}} ->
        {painter, _changed?} = resize_painter(loop, painter, {columns, rows})
        dashboard = %{dashboard | width: columns, height: rows}
        painter = render_agents(dashboard, theme, painter, cast)
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {Ghostty.TTY, ^tty, {:key, %Ghostty.KeyEvent{key: :c, mods: [:ctrl]}}} ->
        PS.unsubscribe(Vibe.PubSub, Session.sessions_topic())
        :ok

      {:session_changed, _session_id} ->
        dashboard = AgentsView.refresh(dashboard)
        painter = render_agents(dashboard, theme, painter, cast)
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {Ghostty.TTY, ^tty, :eof} ->
        PS.unsubscribe(Vibe.PubSub, Session.sessions_topic())
        :ok

      {Ghostty.TTY, ^tty, {:key, _event}} ->
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {Ghostty.TTY, ^tty, {:data, _data}} ->
        agents_receive(tty, loop, dashboard, theme, painter, cast)

      {TerminalLoop, :event, _event} ->
        agents_receive(tty, loop, dashboard, theme, painter, cast)
    end
  end

  defp agents_attach(tty, loop, dashboard, painter, cast) do
    PS.unsubscribe(Vibe.PubSub, Session.sessions_topic())

    case AgentsView.selected_session(dashboard) do
      %{id: session_id} ->
        runtime_id = Process.get(:vibe_runtime_id)
        session_name = RuntimeSupervisor.name(runtime_id, :session)

        case GenServer.whereis(session_name) do
          pid when is_pid(pid) ->
            Session.emit_transient_event(
              pid,
              Event.new(:session_selected, session_id, Vibe.Event.Session.selected(session_id))
            )

          nil ->
            :ok
        end

      nil ->
        :ok
    end

    painter = TerminalPainter.force_full_redraw(painter)
    painter = render(loop, painter, cast)
    receive_events(tty, loop, nil, painter, cast)
  end

  defp render_agents(dashboard, theme, painter, cast) do
    lines = AgentsView.render(dashboard, theme)
    row = min(dashboard.selected + 5, length(lines))
    cursor = {row, 1}
    {frame, painter} = TerminalPainter.render(%{painter | lines: []}, lines, cursor)
    write_output(frame, cast)
    painter
  end

  defp set_window_title(title), do: IO.write(:stderr, "\e]0;#{title}\a")
  defp restore_window_title, do: IO.write(:stderr, "\e]0;\a")

  defp update_title_from_event(%{type: :assistant_stream_started}),
    do: set_window_title("Vibe · working")

  defp update_title_from_event(%{type: :assistant_stream_finished}),
    do: set_window_title("Vibe")

  defp update_title_from_event(%{
         type: :model_selected,
         data: %Vibe.Event.Model.Selected{model: model}
       }),
       do: set_window_title("Vibe · #{model}")

  defp update_title_from_event(%{type: :model_selected, data: %{model: model}}),
    do: set_window_title("Vibe · #{model}")

  defp update_title_from_event(%{
         type: :status_changed,
         data: %Vibe.Event.Surface.StatusChanged{status: :working}
       }),
       do: set_window_title("Vibe · working")

  defp update_title_from_event(%{type: :status_changed, data: %{status: :working}}),
    do: set_window_title("Vibe · working")

  defp update_title_from_event(%{type: :status_changed}),
    do: set_window_title("Vibe")

  defp update_title_from_event(_event), do: :ok

  defp emit_osc133(%{type: :user_message_added}), do: IO.write(:stdio, "\e]133;B\a")
  defp emit_osc133(%{type: :assistant_stream_started}), do: IO.write(:stdio, "\e]133;C\a")

  defp emit_osc133(%{type: :assistant_message_added}),
    do: IO.write(:stdio, "\e]133;D;0\a\e]133;A\a")

  defp emit_osc133(_event), do: :ok

  defp ensure_interactive_terminal do
    if :prim_tty.isatty(:stdin) do
      :ok
    else
      {:error, :stdio_is_not_a_terminal}
    end
  end
end
