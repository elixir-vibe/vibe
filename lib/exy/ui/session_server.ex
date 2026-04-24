defmodule Exy.UI.SessionServer do
  @moduledoc """
  UI-facing session process shared by future TUI and LiveView adapters.

  It owns UI-neutral state, accepts UI-neutral commands, emits events to
  subscribers, and delegates model work through an injectable ask function.
  """

  use GenServer

  alias Exy.LLM
  alias Exy.LLM.Usage
  alias Exy.UI.{Command, Event, Reducer, State}

  @type ask_fun :: (String.t(), keyword() -> {:ok, term()} | {:error, term()})

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) when is_pid(pid),
    do: GenServer.call(server, {:subscribe, pid})

  @spec state(GenServer.server()) :: State.t()
  def state(server), do: GenServer.call(server, :state)

  @spec dispatch(GenServer.server(), Command.t() | atom() | {atom(), map()}) :: :ok
  def dispatch(server, command),
    do: GenServer.call(server, {:dispatch, normalize_command(command)})

  @impl true
  def init(opts) do
    state = State.new(opts)

    {:ok,
     %{
       state: state,
       ask_fun: Keyword.get(opts, :ask_fun, &default_ask/2),
       subscribers: %{}
     }}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    subscribers = Map.put(state.subscribers, ref, pid)
    {:reply, :ok, %{state | subscribers: subscribers}}
  end

  def handle_call(:state, _from, state), do: {:reply, state.state, state}

  def handle_call({:dispatch, %Command{} = command}, _from, state) do
    {:reply, :ok, handle_command(command, state)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info({:prompt_result, result}, state) do
    state = record_prompt_result(state, result)
    {:noreply, state}
  end

  defp handle_command(%Command{type: :submit_prompt, data: %{text: text}}, state)
       when is_binary(text) do
    session_id = state.state.session_id
    state = emit(state, Event.new(:user_message_added, session_id, %{text: text}))
    ask_fun = state.ask_fun
    parent = self()

    Task.start(fn -> send(parent, {:prompt_result, ask_fun.(text, session_id: session_id)}) end)
    state
  end

  defp handle_command(%Command{type: :open_overlay, data: data}, state) do
    emit(state, Event.new(:overlay_opened, state.state.session_id, data))
  end

  defp handle_command(%Command{type: :close_overlay}, state) do
    emit(state, Event.new(:overlay_closed, state.state.session_id, %{}))
  end

  defp handle_command(%Command{type: type, data: data}, state) do
    emit(state, Event.new(type, state.state.session_id, data))
  end

  defp record_prompt_result(state, {:ok, response}) do
    data = %{result: response}
    state = emit(state, Event.new(:assistant_message_added, state.state.session_id, data))

    case Usage.from_response(response) do
      nil -> state
      usage -> emit(state, Event.new(:usage_updated, state.state.session_id, usage))
    end
  end

  defp record_prompt_result(state, {:error, reason}) do
    emit(
      state,
      Event.new(:assistant_message_added, state.state.session_id, %{error: inspect(reason)})
    )
  end

  defp emit(state, event) do
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {:exy_ui_event, event}) end)
    %{state | state: Reducer.apply_event(state.state, event)}
  end

  defp normalize_command(%Command{} = command), do: command
  defp normalize_command(type) when is_atom(type), do: Command.new(type)

  defp normalize_command({type, data}) when is_atom(type) and is_map(data),
    do: Command.new(type, data)

  defp default_ask(text, opts), do: LLM.ask(text, opts)
end
