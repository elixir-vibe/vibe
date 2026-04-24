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

  @spec emit_event(GenServer.server(), Event.t()) :: :ok
  def emit_event(server, %Event{} = event), do: GenServer.call(server, {:emit_event, event})

  @impl true
  def init(opts) do
    state = State.new(opts)

    maybe_register_ui_bus(state.session_id)
    dispatch_plugin_lifecycle(:session_started, %{}, state)

    {:ok,
     %{
       state: state,
       ask_fun: Keyword.get(opts, :ask_fun, &default_ask/2),
       streaming?: not Keyword.has_key?(opts, :ask_fun),
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

  def handle_call({:emit_event, %Event{} = event}, _from, state) do
    {:reply, :ok, emit(state, event)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info({:prompt_result, result}, state) do
    state = record_prompt_result(state, result)
    {:noreply, state}
  end

  def handle_info({:assistant_delta, text}, state) do
    {:noreply, emit(state, Event.new(:assistant_delta, state.state.session_id, %{text: text}))}
  end

  def handle_info({:assistant_thinking_delta, text}, state) do
    {:noreply,
     emit(state, Event.new(:assistant_thinking_delta, state.state.session_id, %{text: text}))}
  end

  defp handle_command(%Command{type: :submit_prompt, data: %{text: text}}, state)
       when is_binary(text) do
    session_id = state.state.session_id
    state = emit(state, Event.new(:prompt_submitted, session_id, %{text: text}))
    state = emit(state, Event.new(:user_message_added, session_id, %{text: text}))
    ask_fun = state.ask_fun
    parent = self()

    {ask_opts, state} = ask_options(state, parent, session_id)

    Task.start(fn -> send(parent, {:prompt_result, ask_fun.(text, ask_opts)}) end)

    state
  end

  defp handle_command(
         %Command{type: :slash_command_submitted, data: %{command: command} = data},
         state
       ) do
    state = emit(state, Event.new(:slash_command_submitted, state.state.session_id, data))

    case slash_selector(command, state.state) do
      nil -> state
      selector -> emit(state, Event.new(:selector_opened, state.state.session_id, selector))
    end
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

  defp ask_options(%{streaming?: true} = state, parent, session_id) do
    state = emit(state, Event.new(:assistant_stream_started, session_id, %{}))

    {[
       session_id: session_id,
       on_result: &send(parent, {:assistant_delta, &1}),
       on_thinking: &send(parent, {:assistant_thinking_delta, &1})
     ], state}
  end

  defp ask_options(state, _parent, session_id), do: {[session_id: session_id], state}

  defp record_prompt_result(state, {:ok, response}) do
    state =
      if state.state.streaming_message do
        emit(state, Event.new(:assistant_stream_finished, state.state.session_id, %{}))
      else
        data = %{result: response}
        emit(state, Event.new(:assistant_message_added, state.state.session_id, data))
      end

    case Usage.from_response(response) do
      nil -> state
      usage -> emit(state, Event.new(:usage_updated, state.state.session_id, usage))
    end
  end

  defp record_prompt_result(state, {:error, reason}) do
    state =
      emit(
        state,
        Event.new(:assistant_aborted, state.state.session_id, %{reason: inspect(reason)})
      )

    emit(
      state,
      Event.new(:assistant_message_added, state.state.session_id, %{error: inspect(reason)})
    )
  end

  defp emit(state, event) do
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {:exy_ui_event, event}) end)
    dispatch_plugin_event(state.state, event)
    %{state | state: Reducer.apply_event(state.state, event)}
  end

  defp dispatch_plugin_event(ui_state, event) do
    dispatch_plugin_lifecycle(event.type, event.data, ui_state, plugin_event?(event.type))
  end

  defp dispatch_plugin_lifecycle(type, data, ui_state, enabled? \\ true) do
    if enabled? and Process.whereis(Exy.Plugin.Manager) do
      context = %{session_id: ui_state.session_id, cwd: ui_state.cwd, model: ui_state.model}
      Task.start(fn -> Exy.Plugin.Manager.dispatch(type, data, context) end)
    end

    :ok
  end

  defp plugin_event?(:plugin_status_updated), do: false
  defp plugin_event?(:plugin_status_cleared), do: false
  defp plugin_event?(:plugin_widget_updated), do: false
  defp plugin_event?(:plugin_widget_cleared), do: false
  defp plugin_event?(:notification_added), do: false
  defp plugin_event?(:notification_expired), do: false
  defp plugin_event?(_type), do: true

  defp normalize_command(%Command{} = command), do: command
  defp normalize_command(type) when is_atom(type), do: Command.new(type)

  defp normalize_command({type, data}) when is_atom(type) and is_map(data),
    do: Command.new(type, data)

  defp slash_selector("model", ui_state) do
    %{kind: :model_selector, title: "Model", items: [ui_state.model], selected: 0, limit: 8}
  end

  defp slash_selector("session", _ui_state) do
    items = Exy.Session.list() |> Enum.map(& &1.id)
    %{kind: :session_selector, title: "Session", items: items, selected: 0, limit: 8}
  end

  defp slash_selector("skill", _ui_state) do
    items = Exy.Skill.list() |> Enum.map(& &1.name)
    %{kind: :skill_selector, title: "Skill", items: items, selected: 0, limit: 8}
  end

  defp slash_selector("commands", _ui_state) do
    %{
      kind: :command_palette,
      title: "Commands",
      items: ["model", "session", "skill", "clear", "compact"],
      selected: 0,
      limit: 8
    }
  end

  defp slash_selector(_command, _ui_state), do: nil

  defp maybe_register_ui_bus(session_id) do
    if Process.whereis(Exy.UI.Bus), do: Exy.UI.Bus.register(session_id, self()), else: :ok
  end

  defp default_ask(text, opts) do
    if Keyword.has_key?(opts, :on_result) or Keyword.has_key?(opts, :on_thinking) do
      LLM.stream(text, opts)
    else
      LLM.ask(text, opts)
    end
  end
end
