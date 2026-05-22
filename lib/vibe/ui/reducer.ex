defmodule Vibe.UI.Reducer do
  @moduledoc """
  Pure reducer for Vibe's UI-neutral event stream.
  """

  alias Vibe.Event
  alias Vibe.Model.Usage
  alias Vibe.SystemAlarms.Alert
  alias Vibe.Support.Lists
  alias Vibe.Tool.Event, as: ToolEvent
  alias Vibe.UI.{Message, Notification, Selector, State}

  @spec apply_event(State.t(), Event.t()) :: State.t()
  def apply_event(%State{} = state, %Event{} = event) do
    state
    |> Map.update!(:events, &Lists.append(&1, event))
    |> reduce(event)
  end

  @spec apply_events(State.t(), [Event.t()]) :: State.t()
  def apply_events(%State{} = state, events), do: Enum.reduce(events, state, &apply_event(&2, &1))

  defp reduce(state, %Event{
         type: :user_message_added,
         at: at,
         data: %Vibe.Event.Message.UserAdded{
           text: text,
           content: content,
           image_count: image_count
         }
       }) do
    append_user_message(state, text, at, content, image_count)
  end

  defp reduce(state, %Event{type: :user_message_added, at: at, data: data}) do
    data = event_payload_map(data)

    append_user_message(
      state,
      Map.fetch!(data, :text),
      at,
      Map.get(data, :content),
      Map.get(data, :image_count)
    )
  end

  defp reduce(state, %Event{
         type: :assistant_message_added,
         at: at,
         data: %Vibe.Event.Message.AssistantAdded{} = data
       }) do
    append_assistant_message(state, data, at)
  end

  defp reduce(state, %Event{type: :assistant_message_added, at: at, data: data}) do
    append_assistant_message(state, event_payload_map(data), at)
  end

  defp reduce(state, %Event{type: :assistant_stream_started}) do
    %{
      state
      | streaming_message: %Message{role: :assistant, text: "", thinking: ""},
        status: :working
    }
  end

  defp reduce(state, %Event{
         type: :assistant_delta,
         at: at,
         data: %Vibe.Event.AssistantStream.Delta{text: text}
       }) do
    apply_assistant_delta(state, text, at)
  end

  defp reduce(state, %Event{type: :assistant_delta, at: at, data: data}) do
    %{text: text} = event_payload_map(data)
    apply_assistant_delta(state, text, at)
  end

  defp reduce(state, %Event{
         type: :assistant_thinking_delta,
         at: at,
         data: %Vibe.Event.AssistantStream.ThinkingDelta{text: text}
       }) do
    append_streaming_delta(state, :thinking, text, at)
  end

  defp reduce(state, %Event{type: :assistant_thinking_delta, at: at, data: data}) do
    %{text: text} = event_payload_map(data)
    append_streaming_delta(state, :thinking, text, at)
  end

  defp reduce(state, %Event{
         type: :assistant_stream_finished,
         at: at,
         data: %Vibe.Event.AssistantStream.Finished{text: text}
       }) do
    finish_assistant_stream(state, text, at)
  end

  defp reduce(state, %Event{type: :assistant_stream_finished, at: at, data: data}) do
    data = event_payload_map(data)
    finish_assistant_stream(state, Map.get(data, :text), at)
  end

  defp reduce(state, %Event{
         type: :assistant_aborted,
         data: %Vibe.Event.AssistantStream.Aborted{reason: reason, notify?: notify?}
       }) do
    abort_assistant(state, reason, notify?)
  end

  defp reduce(state, %Event{type: :assistant_aborted, data: data}) do
    data = event_payload_map(data)
    abort_assistant(state, Map.get(data, :reason, "Cancelled."), Map.get(data, :notify?, true))
  end

  defp reduce(state, %Event{
         type: :tool_started,
         at: at,
         data: %Vibe.Event.Tool.Started{event: %ToolEvent{id: id} = data}
       }) do
    data = tool_event_map(data)

    {messages, pending_tools} =
      case Map.fetch(state.pending_tools, id) do
        {:ok, _tool} ->
          tool = Map.update!(state.pending_tools, id, &Map.merge(&1, data))
          {update_tool_message(state.messages, id, data), tool}

        :error ->
          tool = Map.put_new(data, :expanded?, false)
          tool_message = tool |> Map.put(:role, :tool) |> Map.put(:at, at)
          {Lists.append(state.messages, tool_message), Map.put(state.pending_tools, id, tool)}
      end

    %{
      state
      | messages: messages,
        pending_tools: pending_tools,
        status: :working
    }
  end

  defp reduce(state, %Event{
         type: :tool_finished,
         data: %Vibe.Event.Tool.Finished{event: %ToolEvent{id: id} = data}
       }) do
    data = tool_event_map(data)
    pending_tools = Map.update(state.pending_tools, id, data, &Map.merge(&1, data))

    %{
      state
      | messages: update_tool_message(state.messages, id, data),
        pending_tools: pending_tools,
        status: maybe_idle_after_tool_finished(state, pending_tools)
    }
  end

  defp reduce(state, %Event{
         type: :tool_updated,
         at: at,
         data: %Vibe.Event.Tool.Updated{event: %ToolEvent{id: id} = data}
       }) do
    data = tool_event_map(data)

    {messages, pending_tools} =
      case Map.fetch(state.pending_tools, id) do
        {:ok, _tool} ->
          pending_tools = Map.update!(state.pending_tools, id, &Map.merge(&1, data))
          {update_tool_message(state.messages, id, data), pending_tools}

        :error ->
          tool = data |> Map.put_new(:expanded?, false)
          tool_message = tool |> Map.put(:role, :tool) |> Map.put(:at, at)
          {Lists.append(state.messages, tool_message), Map.put(state.pending_tools, id, tool)}
      end

    %{
      state
      | messages: messages,
        pending_tools: pending_tools,
        status: :working
    }
  end

  defp reduce(state, %Event{type: :goal_set, data: %Vibe.Event.Goal.Set{goal: goal}}) do
    %{state | goal: goal, messages: Lists.append(state.messages, goal_message(goal, "Goal set"))}
  end

  defp reduce(state, %Event{type: :goal_updated, data: %Vibe.Event.Goal.Updated{goal: goal}}) do
    %{
      state
      | goal: goal,
        messages: Lists.append(state.messages, goal_message(goal, "Goal updated"))
    }
  end

  defp reduce(state, %Event{
         type: :goal_continuation_started,
         data: %Vibe.Event.Goal.ContinuationStarted{}
       }) do
    %{state | status: :working}
  end

  defp reduce(state, %Event{type: :goal_cleared, data: %Vibe.Event.Goal.Cleared{}, at: at}) do
    %{
      state
      | goal: nil,
        messages: Lists.append(state.messages, system_message("Goal cleared", at))
    }
  end

  defp reduce(state, %Event{type: :truncation_toggled}) do
    %{state | truncate?: !state.truncate?}
  end

  defp reduce(state, %Event{type: :tool_toggled, data: %Vibe.Event.Surface.ToolToggled{id: id}}) do
    toggle_tool(state, id)
  end

  defp reduce(state, %Event{type: :tool_toggled, data: data}) do
    %{id: id} = event_payload_map(data)
    toggle_tool(state, id)
  end

  defp reduce(state, %Event{
         type: :patch_confirmation_requested,
         data: %Vibe.Event.Command.PatchConfirmationRequested{} = data
       }) do
    open_patch_confirmation(state, event_payload_map(data))
  end

  defp reduce(state, %Event{type: :patch_confirmation_requested, data: data}) do
    open_patch_confirmation(state, event_payload_map(data))
  end

  defp reduce(state, %Event{type: :usage_updated, data: usage}) do
    usage = event_payload_map(usage)
    %{state | usage: Usage.summarize([state.usage, usage]), usage_preview: empty_usage_preview()}
  end

  defp reduce(state, %Event{
         type: :status_changed,
         data: %Vibe.Event.Surface.StatusChanged{status: status}
       }) do
    %{state | status: status}
  end

  defp reduce(state, %Event{type: :status_changed, data: data}) do
    %{status: status} = event_payload_map(data)
    %{state | status: status}
  end

  defp reduce(state, %Event{
         type: :model_selected,
         at: at,
         data: %Vibe.Event.Model.Selected{model: model}
       }) do
    %{
      state
      | model: model,
        messages:
          state.messages
          |> drop_trailing_session_marker(:model_selected)
          |> Lists.append(model_selected_message(model, at))
    }
  end

  defp reduce(state, %Event{
         type: :model_selected,
         at: at,
         data: data
       }) do
    %{model: model} = event_payload_map(data)

    %{
      state
      | model: model,
        messages:
          state.messages
          |> drop_trailing_session_marker(:model_selected)
          |> Lists.append(model_selected_message(model, at))
    }
  end

  defp reduce(state, %Event{
         type: :effort_selected,
         at: at,
         data: %Vibe.Event.Model.EffortSelected{effort: effort}
       }) do
    %{
      state
      | effort: effort,
        messages: Lists.append(state.messages, effort_selected_message(effort, at))
    }
  end

  defp reduce(state, %Event{
         type: :effort_selected,
         at: at,
         data: data
       }) do
    %{effort: effort} = event_payload_map(data)

    %{
      state
      | effort: effort,
        messages: Lists.append(state.messages, effort_selected_message(effort, at))
    }
  end

  defp reduce(state, %Event{
         type: :session_selected,
         data: %Vibe.Event.Session.Selected{session_id: session_id}
       }) do
    %{state | session_id: session_id}
  end

  defp reduce(state, %Event{type: :session_selected, data: data}) do
    %{session_id: session_id} = event_payload_map(data)
    %{state | session_id: session_id}
  end

  defp reduce(state, %Event{type: :messages_cleared}) do
    %{
      state
      | messages: [],
        pending_tools: %{},
        streaming_message: nil,
        usage_preview: empty_usage_preview(),
        status: :idle
    }
  end

  defp reduce(state, %Event{
         type: :context_compaction_started,
         data: %Vibe.Event.ContextCompaction.Started{tokens_before: tokens_before}
       }) do
    start_context_compaction(state, tokens_before)
  end

  defp reduce(state, %Event{type: :context_compaction_started, data: data}) do
    data = event_payload_map(data)
    start_context_compaction(state, Map.get(data, :tokens_before, 0))
  end

  defp reduce(state, %Event{
         type: :context_compaction_failed,
         data: %Vibe.Event.ContextCompaction.Failed{reason: reason}
       }) do
    fail_context_compaction(state, reason)
  end

  defp reduce(state, %Event{type: :context_compaction_failed, data: data}) do
    data = event_payload_map(data)
    fail_context_compaction(state, Map.get(data, :reason, "context compaction failed"))
  end

  defp reduce(state, %Event{
         type: :context_compaction_finished,
         data: %Vibe.Event.ContextCompaction.Finished{summary: summary}
       }) do
    finish_context_compaction(state, summary)
  end

  defp reduce(state, %Event{type: :context_compaction_finished, data: data}) do
    data = event_payload_map(data)
    finish_context_compaction(state, Map.get(data, :summary, "context compacted"))
  end

  defp reduce(state, %Event{
         type: :overlay_opened,
         data: %Vibe.Event.Surface.OverlayOpened{overlay: overlay}
       }) do
    %{state | overlays: Lists.append(state.overlays, overlay)}
  end

  defp reduce(state, %Event{type: :overlay_opened, data: data}) do
    %{state | overlays: Lists.append(state.overlays, event_payload_map(data))}
  end

  defp reduce(state, %Event{type: :overlay_closed}) do
    %{state | overlays: Enum.drop(state.overlays, -1)}
  end

  defp reduce(state, %Event{
         type: :notification_added,
         id: event_id,
         data: %Vibe.Event.Notification.Added{} = data
       }) do
    add_notification(state, event_payload_map(data), event_id)
  end

  defp reduce(state, %Event{type: :notification_added, id: event_id, data: data}) do
    add_notification(state, event_payload_map(data), event_id)
  end

  defp reduce(state, %Event{
         type: :runtime_alert_set,
         data: %Vibe.Event.RuntimeAlert.Set{alert: %Alert{} = alert}
       }) do
    set_runtime_alert(state, alert)
  end

  defp reduce(state, %Event{
         type: :runtime_alert_clear,
         data: %Vibe.Event.RuntimeAlert.Cleared{alert: %Alert{} = alert}
       }) do
    clear_runtime_alert(state, alert)
  end

  defp reduce(state, %Event{
         type: :notification_expired,
         data: %Vibe.Event.Notification.Expired{id: id}
       }) do
    expire_notification(state, id)
  end

  defp reduce(state, %Event{type: :notification_expired, data: data}) do
    %{id: id} = event_payload_map(data)
    expire_notification(state, id)
  end

  defp reduce(state, %Event{
         type: :subagent_started,
         at: at,
         data: %Vibe.Event.Subagent.Started{} = data
       }) do
    add_subagent_lifecycle(state, event_payload_map(data), :started, at)
  end

  defp reduce(state, %Event{type: :subagent_started, at: at, data: data}) do
    add_subagent_lifecycle(state, event_payload_map(data), :started, at)
  end

  defp reduce(state, %Event{
         type: :subagent_finished,
         at: at,
         data: %Vibe.Event.Subagent.Finished{} = data
       }) do
    add_subagent_lifecycle(state, event_payload_map(data), :finished, at)
  end

  defp reduce(state, %Event{type: :subagent_finished, at: at, data: data}) do
    add_subagent_lifecycle(state, event_payload_map(data), :finished, at)
  end

  defp reduce(state, %Event{
         type: :active_sessions_updated,
         data: %Vibe.Event.Session.ActiveCountUpdated{count: count}
       }) do
    %{state | active_sessions: count}
  end

  defp reduce(state, %Event{type: :active_sessions_updated, data: data}) do
    %{count: count} = event_payload_map(data)
    %{state | active_sessions: count}
  end

  defp reduce(state, %Event{
         type: :plugin_status_updated,
         data: %Vibe.Event.Plugin.StatusUpdated{key: key, text: text}
       }) do
    put_plugin_status(state, key, text)
  end

  defp reduce(state, %Event{type: :plugin_status_updated, data: data}) do
    %{key: key, text: text} = event_payload_map(data)
    put_plugin_status(state, key, text)
  end

  defp reduce(state, %Event{
         type: :plugin_status_cleared,
         data: %Vibe.Event.Plugin.StatusCleared{key: key}
       }) do
    clear_plugin_status(state, key)
  end

  defp reduce(state, %Event{type: :plugin_status_cleared, data: data}) do
    %{key: key} = event_payload_map(data)
    clear_plugin_status(state, key)
  end

  defp reduce(state, %Event{
         type: :plugin_widget_updated,
         data: %Vibe.Event.Plugin.WidgetUpdated{widget: widget}
       }) do
    put_plugin_widget(state, widget)
  end

  defp reduce(state, %Event{type: :plugin_widget_updated, data: data}) do
    %{widget: widget} = event_payload_map(data)
    put_plugin_widget(state, widget)
  end

  defp reduce(state, %Event{
         type: :plugin_widget_cleared,
         data: %Vibe.Event.Plugin.WidgetCleared{key: key}
       }) do
    clear_plugin_widget(state, key)
  end

  defp reduce(state, %Event{type: :plugin_widget_cleared, data: data}) do
    %{key: key} = event_payload_map(data)
    clear_plugin_widget(state, key)
  end

  defp reduce(state, %Event{
         type: :working_message_updated,
         data: %Vibe.Event.Surface.WorkingMessageUpdated{message: message}
       }) do
    %{state | working_message: message}
  end

  defp reduce(state, %Event{type: :working_message_updated, data: data}) do
    %{message: message} = event_payload_map(data)
    %{state | working_message: message}
  end

  defp reduce(state, %Event{
         type: :hidden_thinking_label_updated,
         data: %Vibe.Event.Surface.HiddenThinkingLabelUpdated{label: label}
       }) do
    %{state | hidden_thinking_label: label}
  end

  defp reduce(state, %Event{type: :hidden_thinking_label_updated, data: data}) do
    %{label: label} = event_payload_map(data)
    %{state | hidden_thinking_label: label}
  end

  defp reduce(state, %Event{
         type: :title_updated,
         data: %Vibe.Event.Surface.TitleUpdated{title: title}
       }) do
    %{state | title: title}
  end

  defp reduce(state, %Event{type: :title_updated, data: data}) do
    %{title: title} = event_payload_map(data)
    %{state | title: title}
  end

  defp reduce(state, %Event{
         type: :selector_opened,
         data: %Vibe.Event.Selector.Opened{selector: selector}
       }) do
    open_selector(state, selector)
  end

  defp reduce(state, %Event{type: :selector_opened, data: data}) do
    open_selector(state, data)
  end

  defp reduce(state, %Event{
         type: :confirmation_requested,
         data: %Vibe.Event.Surface.ConfirmationRequested{confirmation: confirmation}
       }) do
    open_confirmation_selector(state, confirmation)
  end

  defp reduce(state, %Event{type: :confirmation_requested, data: data}) do
    open_confirmation_selector(state, data)
  end

  defp reduce(state, %Event{
         type: :selector_moved,
         data: %Vibe.Event.Selector.Moved{direction: direction}
       }) do
    move_active_selector(state, direction)
  end

  defp reduce(state, %Event{type: :selector_moved, data: data}) do
    %{direction: direction} = event_payload_map(data)
    move_active_selector(state, direction)
  end

  defp reduce(state, %Event{type: :selector_closed}) do
    %{state | selector: nil, overlays: Enum.reject(state.overlays, &selector_overlay?/1)}
  end

  defp reduce(state, %Event{type: :selector_confirmed}) do
    %{state | selector: nil, overlays: Enum.reject(state.overlays, &selector_overlay?/1)}
  end

  defp reduce(state, _event), do: state

  defp toggle_tool(state, id) do
    pending_tools =
      Map.update(state.pending_tools, id, nil, fn
        nil -> nil
        tool -> Map.update(tool, :expanded?, true, &(!&1))
      end)

    %{state | pending_tools: pending_tools}
  end

  defp open_patch_confirmation(state, data) do
    %{state | overlays: Lists.append(state.overlays, Map.put(data, :kind, :patch_confirmation))}
  end

  defp start_context_compaction(state, tokens_before) do
    widget =
      Vibe.Presentation.Widget.progress(:context_compaction,
        title: "Compacting context",
        current: tokens_before,
        total: tokens_before,
        message: "Summarizing conversation history",
        placement: :above_editor
      )

    %{
      state
      | status: :compacting,
        plugin_widgets: Map.put(state.plugin_widgets, widget.id, widget)
    }
  end

  defp fail_context_compaction(state, reason) do
    %{
      state
      | notifications: Lists.append(state.notifications, %{level: :error, text: reason}),
        status: :idle,
        plugin_widgets: Map.delete(state.plugin_widgets, "context_compaction")
    }
  end

  defp finish_context_compaction(state, summary) do
    widget =
      Vibe.Presentation.Widget.markdown(:context_compaction_summary, summary,
        placement: :above_editor,
        version: System.unique_integer([:positive])
      )

    %{
      state
      | notifications: Lists.append(state.notifications, %{level: :success, text: summary}),
        status: :idle,
        plugin_widgets:
          state.plugin_widgets
          |> Map.delete("context_compaction")
          |> Map.put(widget.id, widget)
    }
  end

  defp add_notification(state, data, event_id) do
    %{
      state
      | notifications:
          Lists.append(state.notifications, Notification.new(Map.put_new(data, :id, event_id)))
    }
  end

  defp expire_notification(state, id) do
    %{state | notifications: Enum.reject(state.notifications, &(notification_id(&1) == id))}
  end

  defp add_subagent_lifecycle(state, data, lifecycle, at) do
    child_session_id = Map.get(data, :child_session_id)
    role = Map.get(data, :role) || "subagent"
    status = Map.get(data, :status, lifecycle)
    text = subagent_lifecycle_text(role, lifecycle, status, child_session_id)
    message = Map.merge(data, %{role: :subagent, role_name: role, lifecycle: lifecycle, at: at})

    %{
      state
      | messages: Lists.append(state.messages, message),
        notifications:
          Lists.append(state.notifications, Notification.new(%{level: :info, text: text}))
    }
  end

  defp subagent_lifecycle_text(role, :started, _status, child_session_id) do
    "#{role} started" <> attach_hint(child_session_id)
  end

  defp subagent_lifecycle_text(role, :finished, status, child_session_id) do
    "#{role} finished: #{status}" <> attach_hint(child_session_id)
  end

  defp put_plugin_status(state, key, text) do
    %{state | plugin_statuses: Map.put(state.plugin_statuses, key, text)}
  end

  defp clear_plugin_status(state, key) do
    %{state | plugin_statuses: Map.delete(state.plugin_statuses, key)}
  end

  defp put_plugin_widget(state, widget) do
    widget = Vibe.Presentation.Widget.normalize(widget)
    %{state | plugin_widgets: Map.put(state.plugin_widgets, widget.id, widget)}
  end

  defp clear_plugin_widget(state, key) do
    %{state | plugin_widgets: Map.delete(state.plugin_widgets, key)}
  end

  defp move_active_selector(state, direction) do
    %{
      state
      | selector: move_selector(state.selector, direction),
        overlays: update_selector_overlay(state.overlays, direction)
    }
  end

  defp append_user_message(state, text, at, content, image_count) do
    message =
      %Message{role: :user, text: text, at: at}
      |> maybe_put(:content, content)
      |> maybe_put(:image_count, image_count)

    %{
      state
      | messages: Lists.append(state.messages, message),
        status: :working,
        usage_preview: usage_preview(input_tokens: estimate_tokens(text), output_tokens: 0)
    }
  end

  defp append_assistant_message(state, data, at) do
    message = struct(Message, Map.merge(%{role: :assistant, at: at}, event_payload_map(data)))

    %{
      state
      | messages: Lists.append(state.messages, message),
        status: :idle,
        streaming_message: nil,
        usage_preview: empty_usage_preview()
    }
  end

  defp apply_assistant_delta(state, text, at) do
    state
    |> append_streaming_delta(:text, text, at)
    |> update_usage_preview(:output_tokens, estimate_tokens(text))
  end

  defp finish_assistant_stream(state, text, at) do
    state
    |> finalize_streaming_text(text, at)
    |> Map.merge(%{streaming_message: nil, status: :idle})
  end

  defp abort_assistant(state, reason, notify?) do
    messages =
      if notify? do
        Lists.append(state.messages, %Message{
          role: :assistant,
          text: reason,
          at: DateTime.utc_now()
        })
      else
        state.messages
      end

    %{
      state
      | messages: messages,
        streaming_message: nil,
        status: :idle,
        usage_preview: empty_usage_preview()
    }
  end

  defp open_confirmation_selector(state, data) do
    open_selector(
      state,
      data
      |> Map.put_new(:kind, :confirmation)
      |> Map.put(:overlay_kind, :confirmation)
      |> Map.put_new(:items, [Map.get(data, :confirm, "Yes"), Map.get(data, :cancel, "No")])
      |> Map.put_new(:selected, 0)
      |> Map.put_new(:limit, 2)
    )
  end

  defp open_selector(state, data) do
    selector = Selector.new(data)

    %{
      state
      | selector: selector,
        overlays: Lists.append(state.overlays, Selector.overlay(selector))
    }
  end

  defp selector_overlay?(%{kind: kind}) when kind in [:selector, :confirmation], do: true
  defp selector_overlay?(_overlay), do: false

  defp move_selector(nil, _direction), do: nil

  defp move_selector(%Selector{} = selector, direction), do: Selector.move(selector, direction)

  defp move_selector(selector, direction),
    do: selector |> Selector.new() |> Selector.move(direction)

  defp update_selector_overlay(overlays, direction) do
    Enum.map(overlays, fn
      %{kind: kind} = overlay when kind in [:selector, :confirmation] ->
        overlay
        |> Map.put(:kind, Map.get(overlay, :selector_kind, kind))
        |> Map.put(:overlay_kind, kind)
        |> Selector.new()
        |> Selector.move(direction)
        |> Selector.overlay()

      overlay ->
        overlay
    end)
  end

  defp set_runtime_alert(state, %Alert{} = alert) do
    %{
      state
      | runtime_alerts: Map.put(state.runtime_alerts, alert.id, alert),
        notifications: Lists.append(state.notifications, runtime_alert_notification(alert))
    }
  end

  defp clear_runtime_alert(state, %Alert{} = alert) do
    %{
      state
      | runtime_alerts: Map.delete(state.runtime_alerts, alert.id),
        notifications: Lists.append(state.notifications, runtime_alert_notification(alert))
    }
  end

  defp runtime_alert_notification(%Alert{} = alert) do
    alert
    |> Vibe.Presentation.Presentable.present()
    |> Vibe.Presentation.RuntimeAlert.notification_attrs()
    |> Notification.new()
  end

  defp notification_id(%Notification{id: id}), do: id
  defp notification_id(%{id: id}), do: id
  defp notification_id(_notification), do: nil

  defp finalize_streaming_text(state, "", _at), do: state
  defp finalize_streaming_text(state, text, _at) when not is_binary(text), do: state

  defp finalize_streaming_text(state, text, at) do
    {messages, message} = replace_or_append_assistant_segment(state.messages, :text, text, at)
    %{state | messages: messages, streaming_message: message}
  end

  defp append_streaming_delta(state, key, delta, at) do
    {messages, message} = append_or_update_assistant_segment(state.messages, key, delta, at)
    %{state | messages: messages, streaming_message: message, status: :working}
  end

  defp replace_or_append_assistant_segment(messages, key, value, at) do
    case List.pop_at(messages, -1) do
      {%{role: :assistant, streaming?: true} = message, rest} ->
        updated = Map.put(message, key, value)
        {Lists.append(rest, updated), updated}

      {_last, _rest} ->
        message = %Message{role: :assistant, text: "", thinking: "", at: at, streaming?: true}
        updated = Map.put(message, key, value)
        {Lists.append(messages, updated), updated}
    end
  end

  defp append_or_update_assistant_segment(messages, key, delta, at) do
    case List.pop_at(messages, -1) do
      {%{role: :assistant, streaming?: true} = message, rest} ->
        updated = Map.update(message, key, delta, &(&1 <> delta))
        {Lists.append(rest, updated), updated}

      {_last, _rest} ->
        message = %Message{role: :assistant, text: "", thinking: "", at: at, streaming?: true}
        updated = Map.update(message, key, delta, &(&1 <> delta))
        {Lists.append(messages, updated), updated}
    end
  end

  defp goal_message(goal, label) do
    %{
      role: :system,
      marker: :goal,
      text: label <> ": " <> goal.objective,
      level: :info,
      goal: goal,
      at: DateTime.utc_now()
    }
  end

  defp model_selected_message(model, at) do
    system_message("Model: #{model}", at, marker: :model_selected)
  end

  defp effort_selected_message(effort, at) do
    system_message("Effort: #{Vibe.Model.Effort.label(effort)}", at)
  end

  defp system_message(text, at, opts \\ []) do
    %{role: :system, text: text, level: :info, at: at}
    |> maybe_put(:marker, Keyword.get(opts, :marker))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp event_payload_map(%struct{} = payload) when is_atom(struct) do
    payload
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {payload_key(key), value} end)
  end

  defp event_payload_map(payload) when is_map(payload) do
    Map.new(payload, fn {key, value} -> {payload_key(key), value} end)
  end

  defp payload_key(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> key
  end

  defp payload_key(key), do: key

  defp drop_trailing_session_marker(messages, marker) do
    case List.pop_at(messages, -1) do
      {%{role: :system, marker: ^marker}, rest} -> rest
      {_message, _rest} -> messages
    end
  end

  defp tool_event_map(%ToolEvent{} = event) do
    event
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp maybe_idle_after_tool_finished(
         %{streaming_message: streaming_message} = state,
         pending_tools
       ) do
    cond do
      Enum.any?(pending_tools, fn {_id, tool} ->
        Map.get(tool, :status) in [:running, "running"]
      end) ->
        state.status

      not is_nil(streaming_message) ->
        :working

      true ->
        :idle
    end
  end

  defp update_tool_message(messages, id, data) do
    Enum.map(messages, fn
      %{role: :tool, id: ^id} = tool -> Map.merge(tool, data)
      message -> message
    end)
  end

  defp update_usage_preview(state, key, count) do
    preview =
      state.usage_preview
      |> Map.update(key, count, &(&1 + count))
      |> Map.update(:total_tokens, count, &(&1 + count))

    %{state | usage_preview: preview}
  end

  defp usage_preview(input_tokens: input_tokens, output_tokens: output_tokens) do
    %{
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: input_tokens + output_tokens
    }
  end

  defp empty_usage_preview, do: usage_preview(input_tokens: 0, output_tokens: 0)

  defp attach_hint(session_id) when is_binary(session_id), do: " · attach: vibe a #{session_id}"
  defp attach_hint(_session_id), do: ""

  defp estimate_tokens(""), do: 0
  defp estimate_tokens(text) when is_binary(text), do: max(1, div(String.length(text) + 3, 4))
end
