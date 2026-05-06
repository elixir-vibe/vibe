defmodule Vibe.TUI.App do
  @moduledoc """
  Minimal terminal app coordinator.

  This module keeps terminal mechanics out of semantic UI state. It accepts key
  events and resize events, delegates editing to `Vibe.UI.EditorServer`, and
  dispatches semantic commands to `Vibe.Session`.
  """

  use GenServer

  alias Vibe.Session

  @active_sessions_tick_ms 1_000
  @server_migration_tick_ms 1_000
  alias Vibe.UI.{Autocomplete, Command, EditorServer, FileAutocomplete, Reducer, SlashCommands}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec key(GenServer.server(), Vibe.UI.Editor.key()) :: :ok
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
       active_sessions_task: nil,
       server_migration_timer: server_migration_timer,
       server_migration_fun: server_migration_fun
     }}
  end

  @impl true
  def handle_call({:key, key}, _from, state) do
    state =
      cond do
        app_action_key?(key) ->
          handle_app_action_key(key, state)

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
    state = start_active_sessions_count(state)
    timer = Process.send_after(self(), :active_sessions_tick, @active_sessions_tick_ms)
    {:noreply, %{state | active_sessions_timer: timer}}
  end

  def handle_info({ref, result}, %{active_sessions_task: ref} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish_active_sessions_count(%{state | active_sessions_task: nil}, result)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{active_sessions_task: ref} = state) do
    {:noreply, %{state | active_sessions_task: nil, remote_node: nil}}
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

    with true <- startup_session?(state),
         {:ok, node, _session_id, remote_session} <- state.server_migration_fun.(current),
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
      false ->
        %{state | server_migration_timer: nil}

      _reason ->
        timer = Process.send_after(self(), :server_migration_tick, @server_migration_tick_ms)
        %{state | server_migration_timer: timer}
    end
  end

  defp startup_session?(state) do
    editor = EditorServer.state(state.editor)

    state.ui_snapshot.status == :idle and state.ui_snapshot.messages == [] and editor.text == ""
  end

  defp default_server_migration(current) do
    with {:ok, node} <- Vibe.Remote.connect(),
         {:ok, %{id: session_id}} <-
           Vibe.Remote.Session.start(
             session_id: current.session_id,
             cwd: current.cwd,
             model: current.model
           ),
         {:ok, remote_session} <- Vibe.Remote.Session.lookup(session_id) do
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

  defp start_active_sessions_count(%{active_sessions_task: ref} = state) when is_reference(ref),
    do: state

  defp start_active_sessions_count(state) do
    task = Task.Supervisor.async_nolink(Vibe.TaskSupervisor, &active_sessions_count/0)
    %{state | active_sessions_task: task.ref}
  end

  defp active_sessions_count do
    with {:ok, node} <- Vibe.Remote.connect(),
         count when is_integer(count) <- Vibe.Remote.Session.active_count() do
      {:ok, node, count}
    else
      reason -> {:error, reason}
    end
  end

  defp finish_active_sessions_count(state, {:ok, node, count}) do
    state = %{state | remote_node: node}
    count = max(count, minimum_visible_session_count(state))

    Session.emit_transient_event(
      state.ui,
      Vibe.UI.Event.new(:active_sessions_updated, state.ui_snapshot.session_id, %{count: count})
    )

    state
  end

  defp finish_active_sessions_count(state, _result), do: %{state | remote_node: nil}

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

  defp app_action_key?(key),
    do: key in [:cycle_model_forward, :cycle_model_backward, :open_model_selector, :cycle_effort]

  defp handle_app_action_key(:cycle_model_forward, state) do
    dispatch_async(state.ui, Command.new(:cycle_model, %{direction: :forward}))
    state
  end

  defp handle_app_action_key(:cycle_model_backward, state) do
    dispatch_async(state.ui, Command.new(:cycle_model, %{direction: :backward}))
    state
  end

  defp handle_app_action_key(:open_model_selector, state) do
    dispatch_async(state.ui, Command.new(:open_model_selector))
    state
  end

  defp handle_app_action_key(:cycle_effort, state) do
    dispatch_async(state.ui, Command.new(:cycle_effort))
    state
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
    data = %{selector: Map.get(selector, :kind), item: item}

    dispatch_async(state.ui, Command.new(:selector_confirmed, data))

    apply_local_event(
      state,
      Vibe.UI.Event.new(:selector_confirmed, state.ui_snapshot.session_id, data)
    )
  end

  defp handle_selector_key(:cancel, state) do
    dispatch_async(state.ui, Command.new(:selector_closed))

    apply_local_event(
      state,
      Vibe.UI.Event.new(:selector_closed, state.ui_snapshot.session_id, %{})
    )
  end

  defp handle_selector_key(_key, state), do: state

  defp autocomplete_key?(:submit, %{autocomplete: %Autocomplete{}} = state) do
    state.editor
    |> EditorServer.state()
    |> Map.get(:text, "")
    |> command_prefix_only?()
  end

  defp autocomplete_key?(key, %{autocomplete: %Autocomplete{}}),
    do: key in [:up, :down, :tab, :cancel]

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

  defp handle_autocomplete_key(:cancel, state), do: %{state | autocomplete: nil}

  defp handle_autocomplete_key(:tab, state) do
    case Autocomplete.selected_item(state.autocomplete) do
      %{value: value} ->
        apply_completion(state, value <> " ")

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
        apply_completion(state, value)

      nil ->
        %{state | autocomplete: nil}
    end
  end

  defp apply_completion(state, value) do
    case state.autocomplete.replace_from do
      pos when is_integer(pos) ->
        editor = EditorServer.state(state.editor)
        new_text = String.slice(editor.text, 0, pos) <> value
        :ok = EditorServer.replace(state.editor, new_text)
        %{state | autocomplete: nil}

      nil ->
        :ok = EditorServer.replace(state.editor, value)
        %{state | autocomplete: nil}
    end
  end

  defp refresh_autocomplete(state) do
    editor = EditorServer.state(state.editor)

    autocomplete =
      SlashCommands.autocomplete(editor.text) || FileAutocomplete.autocomplete(editor.text)

    %{state | autocomplete: autocomplete}
  end

  defp remember_event(state, event) do
    %{
      state
      | ui_snapshot: Reducer.apply_event(state.ui_snapshot, event),
        events: [event | state.events]
    }
  end

  defp apply_local_event(state, event) do
    %{state | ui_snapshot: Reducer.apply_event(state.ui_snapshot, event)}
  end

  defp handle_editor_command({:submit, text}, state) do
    dispatch_async(state.ui, submit_prompt_command(text, state))
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

  defp handle_editor_command(:paste_image, state) do
    session_id = state.ui_snapshot.session_id

    case Vibe.Prompt.ClipboardImage.save(session_id: session_id) do
      {:ok, path} ->
        marker = " @#{Path.relative_to(path, state.ui_snapshot.cwd || File.cwd!())}"
        :ok = EditorServer.insert(state.editor, marker)
        refresh_autocomplete(state)

      {:error, reason} ->
        notify_clipboard_image_error(state, reason)
    end
  end

  defp handle_editor_command({:external_editor, text}, state) do
    dispatch_async(state.ui, Command.new(:external_editor_requested, %{text: text}))
  end

  defp notify_clipboard_image_error(state, :pngpaste_not_found) do
    dispatch_async(
      state.ui,
      Command.new(:notification_added, %{
        level: :warning,
        text: "pngpaste is required to paste clipboard images"
      })
    )
  end

  defp notify_clipboard_image_error(state, reason) do
    dispatch_async(
      state.ui,
      Command.new(:notification_added, %{
        level: :warning,
        text: "could not paste clipboard image: #{inspect(reason)}"
      })
    )
  end

  defp submit_prompt_command(text, state) do
    case Vibe.Prompt.Attachments.expand(text, root: state.ui_snapshot.cwd || File.cwd!()) do
      expanded when is_list(expanded) ->
        Command.new(:submit_prompt, %{text: text, content: expanded})

      _text ->
        Command.new(:submit_prompt, %{text: text})
    end
  end

  defp dispatch_async(session, command) do
    _task = Task.start(fn -> Session.dispatch(session, command) end)
    :ok
  end
end
