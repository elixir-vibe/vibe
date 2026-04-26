defmodule Exy.TUI.TerminalLoop do
  @moduledoc """
  Terminal adapter for `Exy.TUI.App`.

  The app remains semantic and testable; this module owns byte decoding,
  viewport size, and terminal repaint commands.
  """

  use GenServer

  alias Exy.TUI
  alias Exy.TUI.{App, KeyDecoder, Lines, Renderer, Theme, Widget, Width}
  alias Exy.UI.ViewModel

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

  @spec render_full(GenServer.server()) :: [IO.chardata()]
  def render_full(server), do: GenServer.call(server, :render_full)

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

    {:ok,
     %{
       app: app,
       output: Keyword.get(opts, :output, :stdio),
       event_target: Keyword.get(opts, :event_target),
       loader_phase: 0,
       loader_timer: nil,
       theme: Keyword.get_lazy(opts, :theme, &Theme.default/0)
     }}
  end

  @impl true
  def handle_call({:input, data}, _from, state) do
    data
    |> KeyDecoder.decode()
    |> Enum.each(&App.key(state.app, &1))

    paint(state)
    {:reply, :ok, state}
  end

  def handle_call({:input_key, event}, _from, state) do
    event
    |> KeyDecoder.decode_event()
    |> Enum.each(&App.key(state.app, &1))

    paint(state)
    {:reply, :ok, state}
  end

  def handle_call({:resize, columns, rows}, _from, state) do
    :ok = App.resize(state.app, columns, rows)
    paint(state)
    {:reply, :ok, state}
  end

  def handle_call(:render, _from, state) do
    {:reply, render_lines(state), state}
  end

  def handle_call(:render_full, _from, state) do
    {:reply, render_full_lines(state), state}
  end

  def handle_call(:cursor_position, _from, state) do
    {:reply, calculate_cursor_position(state), state}
  end

  def handle_call(:full_cursor_position, _from, state) do
    {:reply, calculate_full_cursor_position(state), state}
  end

  def handle_call(:viewport_height, _from, state) do
    {:reply, App.snapshot(state.app).height, state}
  end

  @impl true
  def handle_info({App, :event, event}, state) do
    notify_event_target(state, event)
    paint(state)
    {:noreply, maybe_start_loader_timer(state)}
  end

  def handle_info(:loader_tick, state) do
    if working?(state) do
      state = %{state | loader_phase: state.loader_phase + 1, loader_timer: nil}
      notify_event_target(state, :loader_tick)
      paint(state)
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

  defp paint(%{output: false}), do: :ok

  defp paint(state) do
    lines = render_lines(state)
    IO.write(state.output, [IO.ANSI.home(), IO.ANSI.clear(), Enum.intersperse(lines, "\n")])
  end

  defp render_lines(state) do
    snapshot = App.snapshot(state.app)
    editor = render_editor(snapshot, state.theme)

    state
    |> render_body(snapshot)
    |> fit_body(snapshot.height, editor)
    |> Lines.join(editor)
  end

  defp render_full_lines(state) do
    snapshot = App.snapshot(state.app)
    editor = render_editor(snapshot, state.theme)

    state
    |> render_body(snapshot)
    |> Lines.join(editor)
  end

  defp render_body(state, snapshot) do
    snapshot.ui
    |> ViewModel.from_state()
    |> apply_loader_phase(state.loader_phase)
    |> Renderer.render(snapshot.width, state.theme)
  end

  defp maybe_start_loader_timer(%{loader_timer: nil} = state) do
    if working?(state) do
      %{state | loader_timer: Process.send_after(self(), :loader_tick, 120)}
    else
      state
    end
  end

  defp maybe_start_loader_timer(state), do: state

  defp working?(state), do: App.snapshot(state.app).ui.status == :working

  defp apply_loader_phase(view, phase) do
    Map.update!(view, :body, fn blocks ->
      Enum.map(blocks, fn
        %{id: "streaming", role: :assistant} = block -> Map.put(block, :loader_phase, phase)
        block -> block
      end)
    end)
  end

  defp fit_body(body, height, editor) when is_integer(height) do
    body_lines = max(height - length(editor), 1)
    Enum.take(body, -body_lines)
  end

  defp calculate_cursor_position(state) do
    snapshot = App.snapshot(state.app)
    editor = render_editor(snapshot, state.theme)
    editor_start_row = max(snapshot.height - length(editor), 0)
    editor_cursor_position(snapshot, editor_start_row)
  end

  defp calculate_full_cursor_position(state) do
    snapshot = App.snapshot(state.app)
    editor_start_row = state |> render_body(snapshot) |> length()
    editor_cursor_position(snapshot, editor_start_row)
  end

  defp editor_cursor_position(snapshot, editor_start_row) do
    inner_width = max(snapshot.width - 4, 1)
    text = snapshot.editor.text || ""
    cursor = snapshot.editor.cursor || 0
    before_cursor = String.slice(text, 0, cursor)
    logical_lines = String.split(before_cursor, "\n")
    current_line = List.last(logical_lines) || ""

    previous_rows =
      logical_lines
      |> Enum.drop(-1)
      |> Enum.map(&(&1 |> Widget.wrap(inner_width) |> length()))
      |> Enum.sum()

    current_width = Width.visible_length(current_line)
    row = editor_start_row + 2 + previous_rows + div(current_width, inner_width)
    column = 3 + rem(current_width, inner_width)

    {max(row, 1), max(column, 1)}
  end

  defp render_editor(snapshot, theme) do
    TUI.textarea(
      title: "Prompt",
      value: snapshot.editor.text,
      cursor: snapshot.editor.cursor,
      min_rows: min(max(snapshot.height - 8, 3), 8),
      placeholder: "Ask Exy to change this project..."
    )
    |> Widget.render(snapshot.width, theme)
  end
end
