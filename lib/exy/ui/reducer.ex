defmodule Exy.UI.Reducer do
  @moduledoc """
  Pure reducer for Exy's UI-neutral event stream.
  """

  alias Exy.Model.Usage
  alias Exy.Support.Lists
  alias Exy.UI.{Event, Notification, Selector, State, ToolEvent}

  @spec apply_event(State.t(), Event.t()) :: State.t()
  def apply_event(%State{} = state, %Event{} = event) do
    state
    |> Map.update!(:events, &Lists.append(&1, event))
    |> reduce(event)
  end

  @spec apply_events(State.t(), [Event.t()]) :: State.t()
  def apply_events(%State{} = state, events), do: Enum.reduce(events, state, &apply_event(&2, &1))

  defp reduce(state, %Event{type: :user_message_added, at: at, data: data}) do
    text = Map.fetch!(data, :text)
    message = %{role: :user, text: text, at: at}

    %{
      state
      | messages: Lists.append(state.messages, message),
        status: :working,
        usage_preview: usage_preview(input_tokens: estimate_tokens(text), output_tokens: 0)
    }
  end

  defp reduce(state, %Event{type: :assistant_message_added, at: at, data: data}) do
    message = Map.merge(%{role: :assistant, at: at}, data)

    %{
      state
      | messages: Lists.append(state.messages, message),
        status: :idle,
        streaming_message: nil,
        usage_preview: empty_usage_preview()
    }
  end

  defp reduce(state, %Event{type: :assistant_stream_started}) do
    %{state | streaming_message: %{role: :assistant, text: "", thinking: ""}, status: :working}
  end

  defp reduce(state, %Event{type: :assistant_delta, at: at, data: %{text: text}}) do
    state
    |> append_streaming_delta(:text, text, at)
    |> update_usage_preview(:output_tokens, estimate_tokens(text))
  end

  defp reduce(state, %Event{type: :assistant_thinking_delta, at: at, data: %{text: text}}) do
    append_streaming_delta(state, :thinking, text, at)
  end

  defp reduce(state, %Event{type: :assistant_stream_finished, at: at, data: data}) do
    state
    |> finalize_streaming_text(Map.get(data, :text), at)
    |> Map.merge(%{streaming_message: nil, status: :idle})
  end

  defp reduce(state, %Event{type: :assistant_aborted, data: data}) do
    messages =
      if Map.get(data, :notify?, true) do
        Lists.append(state.messages, %{
          role: :assistant,
          text: Map.get(data, :reason, "Cancelled."),
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

  defp reduce(state, %Event{type: :tool_started, at: at, data: %ToolEvent{id: id} = data}) do
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

  defp reduce(state, %Event{type: :tool_finished, data: %ToolEvent{id: id} = data}) do
    data = tool_event_map(data)
    pending_tools = Map.update(state.pending_tools, id, data, &Map.merge(&1, data))

    %{
      state
      | messages: update_tool_message(state.messages, id, data),
        pending_tools: pending_tools,
        status: maybe_idle_after_tool_finished(state, pending_tools)
    }
  end

  defp reduce(state, %Event{type: :tool_updated, at: at, data: %ToolEvent{id: id} = data}) do
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

  defp reduce(state, %Event{type: :truncation_toggled}) do
    %{state | truncate?: !state.truncate?}
  end

  defp reduce(state, %Event{type: :tool_toggled, data: %{id: id}}) do
    pending_tools =
      Map.update(state.pending_tools, id, nil, fn
        nil -> nil
        tool -> Map.update(tool, :expanded?, true, &(!&1))
      end)

    %{state | pending_tools: pending_tools}
  end

  defp reduce(state, %Event{type: :patch_confirmation_requested, data: data}) do
    %{state | overlays: Lists.append(state.overlays, Map.put(data, :kind, :patch_confirmation))}
  end

  defp reduce(state, %Event{type: :usage_updated, data: usage}) do
    %{state | usage: Usage.summarize([state.usage, usage]), usage_preview: empty_usage_preview()}
  end

  defp reduce(state, %Event{type: :status_changed, data: %{status: status}}) do
    %{state | status: status}
  end

  defp reduce(state, %Event{type: :model_selected, data: %{model: model}}) do
    %{state | model: model}
  end

  defp reduce(state, %Event{type: :effort_selected, data: %{effort: effort}})
       when effort in [:off, :minimal, :low, :medium, :high, :xhigh] do
    %{state | effort: effort}
  end

  defp reduce(state, %Event{type: :session_selected, data: %{session_id: session_id}}) do
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

  defp reduce(state, %Event{type: :context_compaction_started, data: data}) do
    widget =
      Exy.UI.Widget.progress(:context_compaction,
        title: "Compacting context",
        current: Map.get(data, :tokens_before, 0),
        total: Map.get(data, :tokens_before, 0),
        message: "Summarizing conversation history",
        placement: :above_editor
      )

    %{
      state
      | status: :compacting,
        plugin_widgets: Map.put(state.plugin_widgets, widget.id, widget)
    }
  end

  defp reduce(state, %Event{type: :context_compaction_failed, data: data}) do
    notice = %{level: :error, text: Map.get(data, :reason, "context compaction failed")}

    %{
      state
      | notifications: Lists.append(state.notifications, notice),
        status: :idle,
        plugin_widgets: Map.delete(state.plugin_widgets, "context_compaction")
    }
  end

  defp reduce(state, %Event{type: :context_compaction_finished, data: data}) do
    summary = Map.get(data, :summary, "context compacted")
    notice = %{level: :success, text: summary}

    widget =
      Exy.UI.Widget.markdown(:context_compaction_summary, summary,
        placement: :above_editor,
        version: System.unique_integer([:positive])
      )

    %{
      state
      | notifications: Lists.append(state.notifications, notice),
        status: :idle,
        plugin_widgets:
          state.plugin_widgets
          |> Map.delete("context_compaction")
          |> Map.put(widget.id, widget)
    }
  end

  defp reduce(state, %Event{type: :overlay_opened, data: data}) do
    %{state | overlays: Lists.append(state.overlays, data)}
  end

  defp reduce(state, %Event{type: :overlay_closed}) do
    %{state | overlays: Enum.drop(state.overlays, -1)}
  end

  defp reduce(state, %Event{type: :notification_added, data: data}) do
    %{state | notifications: Lists.append(state.notifications, Notification.new(data))}
  end

  defp reduce(state, %Event{type: :notification_expired, data: %{id: id}}) do
    %{state | notifications: Enum.reject(state.notifications, &(notification_id(&1) == id))}
  end

  defp reduce(state, %Event{type: :subagent_started, at: at, data: data}) do
    child_session_id = Map.get(data, :child_session_id)
    role = Map.get(data, :role) || "subagent"
    text = "#{role} started" <> attach_hint(child_session_id)
    message = Map.merge(data, %{role: :subagent, role_name: role, lifecycle: :started, at: at})

    %{
      state
      | messages: Lists.append(state.messages, message),
        notifications:
          Lists.append(state.notifications, Notification.new(%{level: :info, text: text}))
    }
  end

  defp reduce(state, %Event{type: :subagent_finished, at: at, data: data}) do
    child_session_id = Map.get(data, :child_session_id)
    status = Map.get(data, :status, :finished)
    role = Map.get(data, :role) || "subagent"
    text = "#{role} finished: #{status}" <> attach_hint(child_session_id)
    message = Map.merge(data, %{role: :subagent, role_name: role, lifecycle: :finished, at: at})

    %{
      state
      | messages: Lists.append(state.messages, message),
        notifications:
          Lists.append(state.notifications, Notification.new(%{level: :info, text: text}))
    }
  end

  defp reduce(state, %Event{type: :active_sessions_updated, data: %{count: count}}) do
    %{state | active_sessions: count}
  end

  defp reduce(state, %Event{type: :plugin_status_updated, data: %{key: key, text: text}}) do
    %{state | plugin_statuses: Map.put(state.plugin_statuses, key, text)}
  end

  defp reduce(state, %Event{type: :plugin_status_cleared, data: %{key: key}}) do
    %{state | plugin_statuses: Map.delete(state.plugin_statuses, key)}
  end

  defp reduce(state, %Event{type: :plugin_widget_updated, data: %{widget: widget}}) do
    widget = Exy.UI.Widget.normalize(widget)
    %{state | plugin_widgets: Map.put(state.plugin_widgets, widget.id, widget)}
  end

  defp reduce(state, %Event{type: :plugin_widget_cleared, data: %{key: key}}) do
    %{state | plugin_widgets: Map.delete(state.plugin_widgets, key)}
  end

  defp reduce(state, %Event{type: :working_message_updated, data: %{message: message}}) do
    %{state | working_message: message}
  end

  defp reduce(state, %Event{type: :hidden_thinking_label_updated, data: %{label: label}}) do
    %{state | hidden_thinking_label: label}
  end

  defp reduce(state, %Event{type: :title_updated, data: %{title: title}}) do
    %{state | title: title}
  end

  defp reduce(state, %Event{type: :selector_opened, data: data}) do
    open_selector(state, data)
  end

  defp reduce(state, %Event{type: :confirmation_requested, data: data}) do
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

  defp reduce(state, %Event{type: :selector_moved, data: %{direction: direction}}) do
    %{
      state
      | selector: move_selector(state.selector, direction),
        overlays: update_selector_overlay(state.overlays, direction)
    }
  end

  defp reduce(state, %Event{type: :selector_closed}) do
    %{state | selector: nil, overlays: Enum.reject(state.overlays, &selector_overlay?/1)}
  end

  defp reduce(state, %Event{type: :selector_confirmed}) do
    %{state | selector: nil, overlays: Enum.reject(state.overlays, &selector_overlay?/1)}
  end

  defp reduce(state, _event), do: state

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

  defp notification_id(%Notification{id: id}), do: id
  defp notification_id(%{id: id}), do: id
  defp notification_id(_notification), do: nil

  defp finalize_streaming_text(state, text, _at) when not is_binary(text) or text == "", do: state

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
        message = %{role: :assistant, text: "", thinking: "", at: at, streaming?: true}
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
        message = %{role: :assistant, text: "", thinking: "", at: at, streaming?: true}
        updated = Map.update(message, key, delta, &(&1 <> delta))
        {Lists.append(messages, updated), updated}
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

  defp attach_hint(session_id) when is_binary(session_id), do: " · attach: exy a #{session_id}"
  defp attach_hint(_session_id), do: ""

  defp estimate_tokens(""), do: 0
  defp estimate_tokens(text) when is_binary(text), do: max(1, div(String.length(text) + 3, 4))
end
