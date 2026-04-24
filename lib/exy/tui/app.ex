defmodule Exy.TUI.App do
  @moduledoc """
  Minimal terminal app coordinator.

  This module keeps terminal mechanics out of semantic UI state. It accepts key
  events and resize events, delegates editing to `Exy.UI.EditorServer`, and
  dispatches semantic commands to `Exy.UI.SessionServer`.
  """

  use GenServer

  alias Exy.UI.{Command, EditorServer, SessionServer}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec key(GenServer.server(), Exy.UI.Editor.key()) :: :ok
  def key(server, key), do: GenServer.call(server, {:key, key})

  @spec resize(GenServer.server(), pos_integer(), pos_integer()) :: :ok
  def resize(server, columns, rows), do: GenServer.call(server, {:resize, columns, rows})

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) when is_pid(pid),
    do: GenServer.call(server, {:subscribe, pid})

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @impl true
  def init(opts) do
    {:ok, ui} = SessionServer.start_link(opts)
    {:ok, editor} = EditorServer.start_link(history: Keyword.get(opts, :history, []))
    :ok = SessionServer.subscribe(ui, self())

    {:ok,
     %{
       ui: ui,
       editor: editor,
       width: Keyword.get(opts, :width, 100),
       height: Keyword.get(opts, :height, 30),
       events: [],
       subscribers: %{}
     }}
  end

  @impl true
  def handle_call({:key, key}, _from, state) do
    if selector_open?(state) do
      handle_selector_key(key, state)
    else
      commands = EditorServer.key(state.editor, key)
      Enum.each(commands, &handle_editor_command(&1, state))
    end

    {:reply, :ok, state}
  end

  def handle_call({:resize, columns, rows}, _from, state) do
    {:reply, :ok, %{state | width: columns, height: rows}}
  end

  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, ref, pid)}}
  end

  def handle_call(:snapshot, _from, state) do
    snapshot = %{
      ui: SessionServer.state(state.ui),
      editor: EditorServer.state(state.editor),
      width: state.width,
      height: state.height,
      events: Enum.reverse(state.events)
    }

    {:reply, snapshot, state}
  end

  @impl true
  def handle_info({SessionServer, :event, event}, state) do
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
    {:noreply, %{state | events: [event | state.events]}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp selector_open?(state), do: not is_nil(SessionServer.state(state.ui).selector)

  defp handle_selector_key(:up, state) do
    SessionServer.dispatch(state.ui, Command.new(:selector_moved, %{direction: -1}))
  end

  defp handle_selector_key(:down, state) do
    SessionServer.dispatch(state.ui, Command.new(:selector_moved, %{direction: 1}))
  end

  defp handle_selector_key(:submit, state) do
    selector = SessionServer.state(state.ui).selector
    item = selector |> Map.get(:items, []) |> Enum.at(Map.get(selector, :selected, 0))

    SessionServer.dispatch(
      state.ui,
      Command.new(:selector_confirmed, %{selector: Map.get(selector, :kind), item: item})
    )
  end

  defp handle_selector_key(:cancel, state) do
    SessionServer.dispatch(state.ui, Command.new(:selector_closed))
  end

  defp handle_selector_key(_key, _state), do: :ok

  defp handle_editor_command({:submit, text}, state) do
    SessionServer.dispatch(state.ui, Command.new(:submit_prompt, %{text: text}))
  end

  defp handle_editor_command({:slash_command, command, args}, state) do
    SessionServer.dispatch(
      state.ui,
      Command.new(:slash_command_submitted, %{command: command, args: args})
    )
  end

  defp handle_editor_command(:cancel, state) do
    SessionServer.dispatch(state.ui, Command.new(:cancel_stream))
  end

  defp handle_editor_command({:external_editor, text}, state) do
    SessionServer.dispatch(state.ui, Command.new(:external_editor_requested, %{text: text}))
  end
end
