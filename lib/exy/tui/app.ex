defmodule Exy.TUI.App do
  @moduledoc """
  Minimal terminal app coordinator.

  This module keeps terminal mechanics out of semantic UI state. It accepts key
  events and resize events, delegates editing to `Exy.UI.EditorServer`, and
  dispatches semantic commands to `Exy.Session`.
  """

  use GenServer

  alias Exy.Session
  alias Exy.UI.{Autocomplete, Command, EditorServer, Reducer, SlashCommands}

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
    {:ok, ui} = session_server(opts)
    {:ok, editor} = editor_server(opts)
    {:ok, ui_snapshot, _cursor} = Session.attach(ui, self())
    remote_node = Keyword.get(opts, :remote_node)
    active_sessions_timer = Process.send_after(self(), :active_sessions_tick, 0)
    server_migration_timer = maybe_schedule_server_migration(opts)
    server_migration_fun = Keyword.get(opts, :server_migration_fun, &default_server_migration/1)

    {:ok,
     %{
       ui: ui,
       ui_snapshot: ui_snapshot,
       editor: editor,
       width: Keyword.get(opts, :width, 100),
       height: Keyword.get(opts, :height, 30),
       events: [],
       autocomplete: nil,
       subscribers: %{},
       remote_node: remote_node,
       active_sessions_timer: active_sessions_timer,
       server_migration_timer: server_migration_timer,
       server_migration_fun: server_migration_fun
     }}
  end

  @impl true
  def handle_call({:key, key}, _from, state) do
    state =
      cond do
        selector_open?(state) ->
          handle_selector_key(key, state)

        autocomplete_key?(key, state) ->
          handle_autocomplete_key(key, state)

        true ->
          commands = EditorServer.key(state.editor, key)
          Enum.each(commands, &handle_editor_command(&1, state))
          refresh_autocomplete(state)
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
      ui: state.ui_snapshot,
      editor: EditorServer.state(state.editor),
      autocomplete: state.autocomplete,
      width: state.width,
      height: state.height,
      events: Enum.reverse(state.events)
    }

    {:reply, snapshot, state}
  end

  @impl true
  def handle_info(:server_migration_tick, state) do
    state = maybe_migrate_to_remote_session(state)
    {:noreply, state}
  end

  def handle_info(:active_sessions_tick, state) do
    state = publish_active_sessions(state)
    timer = Process.send_after(self(), :active_sessions_tick, 1_000)
    {:noreply, %{state | active_sessions_timer: timer}}
  end

  def handle_info(
        {Session, :event, %{type: :session_selected, data: %{session_id: session_id}} = event},
        state
      ) do
    notify_subscribers(state, event)

    state =
      case switch_session(state, session_id) do
        {:ok, state} -> state
        {:error, reason} -> notify_session_switch_failed(state, session_id, reason)
      end

    {:noreply, remember_event(state, event)}
  end

  def handle_info({Session, :event, %{type: :session_new_requested} = event}, state) do
    notify_subscribers(state, event)

    state =
      case start_new_session(state) do
        {:ok, state} -> state
        {:error, reason} -> notify_session_switch_failed(state, "new", reason)
      end

    {:noreply, remember_event(state, event)}
  end

  def handle_info({Session, :event, event}, state) do
    notify_subscribers(state, event)
    {:noreply, remember_event(state, event)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | subscribers: Map.delete(state.subscribers, ref)}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp maybe_schedule_server_migration(opts) do
    if Keyword.get(opts, :start_server_async, false),
      do: Process.send_after(self(), :server_migration_tick, 500),
      else: nil
  end

  defp maybe_migrate_to_remote_session(%{remote_node: node} = state) when not is_nil(node),
    do: state

  defp maybe_migrate_to_remote_session(state) do
    current = state.ui_snapshot

    with {:ok, node, _session_id, remote_session} <- state.server_migration_fun.(current),
         :ok <- Session.detach(state.ui, self()),
         {:ok, ui_snapshot, _cursor} <- Session.attach(remote_session, self()) do
      Session.dispatch(
        remote_session,
        Command.new(:notification_added, %{level: :info, text: "attached to background server"})
      )

      %{
        state
        | ui: remote_session,
          ui_snapshot: ui_snapshot,
          remote_node: node,
          autocomplete: nil,
          server_migration_timer: nil
      }
    else
      _reason ->
        timer = Process.send_after(self(), :server_migration_tick, 1_000)
        %{state | server_migration_timer: timer}
    end
  end

  defp default_server_migration(current) do
    with {:ok, node} <- Exy.Remote.connect(),
         {:ok, %{id: session_id}} <-
           Exy.Remote.Session.start(
             session_id: current.session_id,
             cwd: current.cwd,
             model: current.model
           ),
         {:ok, remote_session} <- Exy.Remote.Session.lookup(session_id) do
      {:ok, node, session_id, remote_session}
    end
  end

  defp notify_subscribers(state, event) do
    Enum.each(state.subscribers, fn {_ref, pid} -> send(pid, {__MODULE__, :event, event}) end)
  end

  defp switch_session(state, session_id) do
    with {:ok, session} <- Session.lookup(session_id),
         :ok <- Session.detach(state.ui, self()),
         {:ok, ui_snapshot, _cursor} <- Session.attach(session, self()) do
      {:ok, %{state | ui: session, ui_snapshot: ui_snapshot, autocomplete: nil}}
    end
  end

  defp start_new_session(state) do
    current = state.ui_snapshot

    with {:ok, session} <- Session.start_link(cwd: current.cwd, model: current.model),
         :ok <- Session.detach(state.ui, self()),
         {:ok, ui_snapshot, _cursor} <- Session.attach(session, self()) do
      {:ok, %{state | ui: session, ui_snapshot: ui_snapshot, autocomplete: nil}}
    end
  end

  defp notify_session_switch_failed(state, session_id, reason) do
    Session.dispatch(
      state.ui,
      Command.new(:notification_added, %{
        level: :error,
        text: "could not attach #{session_id}: #{inspect(reason)}"
      })
    )

    state
  end

  defp publish_active_sessions(%{remote_node: nil} = state) do
    case Exy.Remote.connect() do
      {:ok, node} -> publish_active_sessions(%{state | remote_node: node})
      {:error, _reason} -> state
    end
  end

  defp publish_active_sessions(state) do
    case Exy.Remote.Session.active_count() do
      count when is_integer(count) ->
        count = max(count, minimum_visible_session_count(state))

        Session.emit_transient_event(
          state.ui,
          Exy.UI.Event.new(:active_sessions_updated, state.ui_snapshot.session_id, %{count: count})
        )

        state

      _other ->
        %{state | remote_node: nil}
    end
  end

  defp minimum_visible_session_count(state) do
    if is_pid(state.ui) and node(state.ui) == state.remote_node, do: 1, else: 0
  end

  defp session_server(opts) do
    case Keyword.fetch(opts, :session_server) do
      {:ok, server} -> {:ok, server}
      :error -> Session.start_link(opts)
    end
  end

  defp editor_server(opts) do
    case Keyword.fetch(opts, :editor_server) do
      {:ok, server} -> {:ok, server}
      :error -> EditorServer.start_link(history: Keyword.get(opts, :history, []))
    end
  end

  defp selector_open?(state), do: not is_nil(state.ui_snapshot.selector)

  defp handle_selector_key(:up, state) do
    Session.dispatch(state.ui, Command.new(:selector_moved, %{direction: -1}))
    state
  end

  defp handle_selector_key(:down, state) do
    Session.dispatch(state.ui, Command.new(:selector_moved, %{direction: 1}))
    state
  end

  defp handle_selector_key(:submit, state) do
    selector = state.ui_snapshot.selector
    item = selector |> Map.get(:items, []) |> Enum.at(Map.get(selector, :selected, 0))

    Session.dispatch(
      state.ui,
      Command.new(:selector_confirmed, %{selector: Map.get(selector, :kind), item: item})
    )

    state
  end

  defp handle_selector_key(:cancel, state) do
    Session.dispatch(state.ui, Command.new(:selector_closed))
    state
  end

  defp handle_selector_key(_key, state), do: state

  defp autocomplete_key?(:submit, %{autocomplete: %Autocomplete{}} = state) do
    state.editor
    |> EditorServer.state()
    |> Map.get(:text, "")
    |> command_prefix_only?()
  end

  defp autocomplete_key?(key, %{autocomplete: %Autocomplete{}}), do: key in [:up, :down, :tab]
  defp autocomplete_key?(_key, _state), do: false

  defp command_prefix_only?("/" <> text) do
    not String.match?(String.trim_leading(text), ~r/\s/)
  end

  defp command_prefix_only?(_text), do: false

  defp handle_autocomplete_key(:up, state) do
    %{state | autocomplete: Autocomplete.move(state.autocomplete, -1)}
  end

  defp handle_autocomplete_key(:down, state) do
    %{state | autocomplete: Autocomplete.move(state.autocomplete, 1)}
  end

  defp handle_autocomplete_key(:tab, state) do
    case Autocomplete.selected_item(state.autocomplete) do
      %{value: value} ->
        :ok = EditorServer.replace(state.editor, value <> " ")
        %{state | autocomplete: nil}

      nil ->
        %{state | autocomplete: nil}
    end
  end

  defp handle_autocomplete_key(:submit, state) do
    case Autocomplete.selected_item(state.autocomplete) do
      %{value: "/" <> command} ->
        :ok = EditorServer.replace(state.editor, "")

        dispatch_async(
          state.ui,
          Command.new(:slash_command_submitted, %{command: command, args: ""})
        )

        %{state | autocomplete: nil}

      %{value: value} ->
        :ok = EditorServer.replace(state.editor, value)
        %{state | autocomplete: nil}

      nil ->
        %{state | autocomplete: nil}
    end
  end

  defp refresh_autocomplete(state) do
    editor = EditorServer.state(state.editor)
    %{state | autocomplete: SlashCommands.autocomplete(editor.text)}
  end

  defp remember_event(state, event) do
    %{
      state
      | ui_snapshot: Reducer.apply_event(state.ui_snapshot, event),
        events: [event | state.events]
    }
  end

  defp handle_editor_command({:submit, text}, state) do
    dispatch_async(state.ui, Command.new(:submit_prompt, %{text: text}))
  end

  defp handle_editor_command({:slash_command, command, args}, state) do
    dispatch_async(
      state.ui,
      Command.new(:slash_command_submitted, %{command: command, args: args})
    )
  end

  defp handle_editor_command(:cancel, state) do
    dispatch_async(state.ui, Command.new(:cancel_stream))
  end

  defp handle_editor_command(:toggle_truncation, state) do
    dispatch_async(state.ui, Command.new(:toggle_truncation))
  end

  defp handle_editor_command({:external_editor, text}, state) do
    dispatch_async(state.ui, Command.new(:external_editor_requested, %{text: text}))
  end

  defp dispatch_async(session, command) do
    _task = Task.start(fn -> Session.dispatch(session, command) end)
    :ok
  end
end
