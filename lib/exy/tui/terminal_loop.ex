defmodule Exy.TUI.TerminalLoop do
  @moduledoc """
  Terminal adapter for `Exy.TUI.App`.

  The app remains semantic and testable; this module owns byte decoding,
  viewport size, and terminal repaint commands.
  """

  use GenServer

  alias Exy.TUI.{App, DSL, KeyDecoder, Renderer, Theme, Widget, Width}
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

  @spec cursor_position(GenServer.server()) :: {pos_integer(), pos_integer()}
  def cursor_position(server), do: GenServer.call(server, :cursor_position)

  @impl true
  def init(opts) do
    {:ok, app} = App.start_link(opts)
    :ok = App.subscribe(app, self())

    {:ok,
     %{
       app: app,
       output: Keyword.get(opts, :output, :stdio),
       event_target: Keyword.get(opts, :event_target),
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

  def handle_call(:cursor_position, _from, state) do
    {:reply, calculate_cursor_position(state), state}
  end

  @impl true
  def handle_info({App, :event, event}, state) do
    notify_event_target(state, event)
    paint(state)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

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
    view = ViewModel.from_state(snapshot.ui)
    editor = render_editor(snapshot, state.theme)

    body =
      view |> Renderer.render(snapshot.width, state.theme) |> fit_body(snapshot.height, editor)

    Exy.TUI.Lines.join(body, editor)
  end

  defp fit_body(body, height, editor) when is_integer(height) do
    body_lines = max(height - length(editor), 1)
    Enum.take(body, -body_lines)
  end

  defp calculate_cursor_position(state) do
    snapshot = App.snapshot(state.app)
    editor = render_editor(snapshot, state.theme)
    editor_start_row = max(snapshot.height - length(editor), 0)
    inner_width = max(snapshot.width - 4, 1)
    left = String.slice(snapshot.editor.text || "", 0, snapshot.editor.cursor || 0)
    left_width = Width.visible_length(left)
    row = editor_start_row + 2 + div(left_width, inner_width)
    column = 3 + rem(left_width, inner_width)

    {max(row, 1), max(column, 1)}
  end

  defp render_editor(snapshot, theme) do
    DSL.textarea(
      title: "Prompt",
      value: snapshot.editor.text,
      cursor: snapshot.editor.cursor,
      min_rows: min(max(snapshot.height - 8, 3), 8),
      placeholder: "Ask Exy to change this project..."
    )
    |> Widget.render(snapshot.width, theme)
  end
end
