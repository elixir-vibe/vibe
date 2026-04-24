defmodule Exy.TUI.TerminalLoop do
  @moduledoc """
  Terminal adapter for `Exy.TUI.App`.

  The app remains semantic and testable; this module owns byte decoding,
  viewport size, and terminal repaint commands.
  """

  use GenServer

  alias Exy.TUI.{App, DSL, KeyDecoder, Renderer, Theme, Widget}
  alias Exy.UI.ViewModel

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec input(GenServer.server(), binary()) :: :ok
  def input(server, data), do: GenServer.call(server, {:input, data})

  @spec resize(GenServer.server(), pos_integer(), pos_integer()) :: :ok
  def resize(server, columns, rows), do: GenServer.call(server, {:resize, columns, rows})

  @spec render(GenServer.server()) :: [IO.chardata()]
  def render(server), do: GenServer.call(server, :render)

  @impl true
  def init(opts) do
    {:ok, app} = App.start_link(opts)

    {:ok,
     %{
       app: app,
       output: Keyword.get(opts, :output, :stdio),
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

  def handle_call({:resize, columns, rows}, _from, state) do
    :ok = App.resize(state.app, columns, rows)
    paint(state)
    {:reply, :ok, state}
  end

  def handle_call(:render, _from, state) do
    {:reply, render_lines(state), state}
  end

  defp paint(%{output: false}), do: :ok

  defp paint(state) do
    lines = render_lines(state)
    IO.write(state.output, [IO.ANSI.home(), IO.ANSI.clear(), Enum.intersperse(lines, "\n")])
  end

  defp render_lines(state) do
    snapshot = App.snapshot(state.app)
    view = ViewModel.from_state(snapshot.ui)
    body = Renderer.render(view, snapshot.width, state.theme)
    editor = render_editor(snapshot, state.theme)
    Exy.TUI.Lines.join(body, editor)
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
