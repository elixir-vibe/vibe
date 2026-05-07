defmodule Vibe.TUI.TerminalLoop do
  @moduledoc """
  Terminal adapter for `Vibe.TUI.App`.

  The app remains semantic and testable; this module owns byte decoding,
  viewport size, and terminal repaint commands.
  """

  use GenServer

  alias Vibe.TUI.{App, Keymap, PickerPresenter, Renderer, RenderState, TerminalPainter, Theme}

  require Vibe.Debug

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec input(GenServer.server(), binary()) :: :ok
  def input(server, data), do: GenServer.call(server, {:input, data})

  @spec input_key(GenServer.server(), Ghostty.KeyEvent.t()) :: :ok
  def input_key(server, %Ghostty.KeyEvent{} = event),
    do: GenServer.call(server, {:input_key, event})

  @spec resize(GenServer.server(), pos_integer(), pos_integer()) :: :ok
  def resize(server, columns, rows), do: GenServer.call(server, {:resize, columns, rows})

  @spec render(GenServer.server()) :: [IO.chardata()]
  def render(server), do: GenServer.call(server, :render)

  @spec render_snapshot(GenServer.server()) :: {[IO.chardata()], {pos_integer(), pos_integer()}}
  def render_snapshot(server), do: GenServer.call(server, :render_snapshot, :infinity)

  @spec render_full(GenServer.server()) :: [IO.chardata()]
  def render_full(server), do: GenServer.call(server, :render_full)

  @spec render_frame(GenServer.server(), :visible | :full) :: Vibe.TUI.RenderFrame.t()
  def render_frame(server, viewport \\ :visible),
    do: GenServer.call(server, {:render_frame, viewport}, :infinity)

  @spec cursor_position(GenServer.server()) :: {pos_integer(), pos_integer()}
  def cursor_position(server), do: GenServer.call(server, :cursor_position)

  @spec full_cursor_position(GenServer.server()) :: {pos_integer(), pos_integer()}
  def full_cursor_position(server), do: GenServer.call(server, :full_cursor_position)

  @spec viewport_height(GenServer.server()) :: pos_integer()
  def viewport_height(server), do: GenServer.call(server, :viewport_height)

  @impl true
  def init(opts) do
    {:ok, app} = app(opts)
    :ok = App.subscribe(app, self())

    snapshot = App.snapshot(app)

    state = %{
      app: app,
      output: Keyword.get(opts, :output, :stdio),
      event_target: Keyword.get(opts, :event_target),
      loader_phase: 0,
      loader_timer: nil,
      loader_tick_ms: Keyword.get(opts, :loader_tick_ms, 120),
      painter: TerminalPainter.new(snapshot.width, snapshot.height),
      render_state: RenderState.new(),
      theme: Keyword.get_lazy(opts, :theme, &Theme.default/0),
      trace:
        Vibe.Debug.run nil do
          Vibe.TUI.Trace.start(opts)
        end
    }

    state =
      Vibe.Debug.run state do
        trace_snapshot(state, :initial)
      end

    {:ok, maybe_start_loader_timer(state)}
  end

  @impl true
  def handle_call({:input, data}, _from, state) do
    state =
      Vibe.Debug.run state do
        trace_record(state, :input, %{bytes: data})
      end

    data
    |> Keymap.from_bytes()
    |> Enum.each(&App.key(state.app, &1))

    state = paint(state, {:input, byte_size(data)})
    {:reply, :ok, state}
  end

  def handle_call({:input_key, event}, _from, state) do
    state =
      Vibe.Debug.run state do
        trace_record(state, :input_key, event)
      end

    event
    |> Keymap.from_event()
    |> Enum.each(&App.key(state.app, &1))

    state = paint(state, {:input_key, event.key})
    {:reply, :ok, state}
  end

  def handle_call({:resize, columns, rows}, _from, state) do
    state =
      Vibe.Debug.run state do
        trace_record(state, :resize, %{columns: columns, rows: rows})
      end

    :ok = App.resize(state.app, columns, rows)
    state = %{state | painter: TerminalPainter.resize(state.painter, columns, rows)}
    state = paint(state, {:resize, columns, rows})
    {:reply, :ok, state}
  end

  def handle_call(:render, _from, state) do
    {lines, state} = render_lines(state)
    {:reply, lines, state}
  end

  def handle_call(:render_full, _from, state) do
    {lines, state} = render_full_lines(state)
    {:reply, lines, state}
  end

  def handle_call(:render_snapshot, _from, state) do
    {frame, state} = build_frame(state, :full)
    {:reply, {frame.lines, frame.cursor}, state}
  end

  def handle_call({:render_frame, viewport}, _from, state) when viewport in [:visible, :full] do
    {frame, state} = build_frame(state, viewport)
    {:reply, frame, state}
  end

  def handle_call(:cursor_position, _from, state) do
    {frame, state} = build_frame(state, :visible)
    {:reply, frame.cursor, state}
  end

  def handle_call(:full_cursor_position, _from, state) do
    {frame, state} = build_frame(state, :full)
    {:reply, frame.cursor, state}
  end

  def handle_call(:viewport_height, _from, state) do
    {:reply, App.snapshot(state.app).height, state}
  end

  @impl true
  def handle_info({App, :event, event}, state) do
    notify_event_target(state, event)

    state =
      Vibe.Debug.run state do
        trace_record(state, :app_event, event)
      end

    state = state |> maybe_reset_render_state(event) |> paint({:app_event, event_type(event)})
    {:noreply, maybe_start_loader_timer(state)}
  end

  def handle_info(:loader_tick, state) do
    if working?(state) do
      state = %{state | loader_phase: state.loader_phase + 1, loader_timer: nil}
      notify_event_target(state, :loader_tick)

      state =
        Vibe.Debug.run state do
          trace_record(state, :loader_tick, %{phase: state.loader_phase})
        end

      state = paint(state, :loader_tick)
      {:noreply, maybe_start_loader_timer(state)}
    else
      {:noreply, %{state | loader_timer: nil}}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp app(opts) do
    case Keyword.fetch(opts, :app) do
      {:ok, app} -> {:ok, app}
      :error -> App.start_link(opts)
    end
  end

  defp notify_event_target(%{event_target: nil}, _event), do: :ok

  defp notify_event_target(%{event_target: target}, event),
    do: send(target, {__MODULE__, :event, event})

  if Vibe.Debug.enabled?() do
    defp paint(%{output: false, trace: nil} = state, _reason), do: state

    defp paint(%{output: false} = state, reason) do
      trace_frame(state, reason)
    end

    defp paint(state, reason) do
      {frame, state} = build_frame(state, :visible)
      {output, painter} = TerminalPainter.render(state.painter, frame.lines, frame.cursor)
      IO.write(state.output, output)

      state
      |> Map.put(:painter, painter)
      |> trace_frame(frame.lines, reason)
    end

    defp trace_record(state, type, payload) do
      %{state | trace: Vibe.TUI.Trace.record(state.trace, type, payload)}
    end

    defp trace_frame(state, reason) do
      {lines, state} = render_lines(state)
      trace_frame(state, lines, reason)
    end

    defp trace_frame(state, lines, reason) do
      state
      |> Map.update!(:trace, &Vibe.TUI.Trace.frame(&1, lines, reason))
      |> trace_snapshot(reason)
    end

    defp trace_snapshot(state, reason) do
      %{state | trace: Vibe.TUI.Trace.snapshot(state.trace, App.snapshot(state.app), reason)}
    end
  else
    defp paint(%{output: false} = state, _reason), do: state

    defp paint(state, _reason) do
      {frame, state} = build_frame(state, :visible)
      {output, painter} = TerminalPainter.render(state.painter, frame.lines, frame.cursor)
      IO.write(state.output, output)
      %{state | painter: painter}
    end
  end

  defp maybe_reset_render_state(state, %{type: :session_selected}),
    do: %{state | render_state: RenderState.new()}

  defp maybe_reset_render_state(state, _event), do: state

  defp event_type(%{type: type}), do: type
  defp event_type(type) when is_atom(type), do: type
  defp event_type(event), do: inspect(event)

  defp render_lines(state) do
    {frame, state} = build_frame(state, :visible)
    {frame.lines, state}
  end

  defp render_full_lines(state) do
    {frame, state} = build_frame(state, :full)
    {frame.lines, state}
  end

  defp build_frame(state, viewport) do
    snapshot = App.snapshot(state.app)

    frame =
      Renderer.render_frame(snapshot, state.theme, state.render_state,
        loader_phase: state.loader_phase,
        picker: PickerPresenter.from_snapshot(snapshot),
        viewport: viewport
      )

    {frame, %{state | render_state: frame.state}}
  end

  defp maybe_start_loader_timer(%{loader_timer: nil} = state) do
    if working?(state) do
      %{state | loader_timer: Process.send_after(self(), :loader_tick, state.loader_tick_ms)}
    else
      state
    end
  end

  defp maybe_start_loader_timer(state), do: state

  defp working?(state), do: App.snapshot(state.app).ui.status == :working
end
