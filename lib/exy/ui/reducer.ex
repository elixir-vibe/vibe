defmodule Exy.UI.Reducer do
  @moduledoc """
  Pure reducer for Exy's UI-neutral event stream.
  """

  alias Exy.{Lists, LLM.Usage}
  alias Exy.UI.{Event, State}

  @spec apply_event(State.t(), Event.t()) :: State.t()
  def apply_event(%State{} = state, %Event{} = event) do
    state
    |> Map.update!(:events, &Lists.append(&1, event))
    |> reduce(event)
  end

  @spec apply_events(State.t(), [Event.t()]) :: State.t()
  def apply_events(%State{} = state, events), do: Enum.reduce(events, state, &apply_event(&2, &1))

  defp reduce(state, %Event{type: :user_message_added, at: at, data: data}) do
    message = %{role: :user, text: Map.fetch!(data, :text), at: at}
    %{state | messages: Lists.append(state.messages, message), status: :working}
  end

  defp reduce(state, %Event{type: :assistant_message_added, at: at, data: data}) do
    message = Map.merge(%{role: :assistant, at: at}, data)

    %{
      state
      | messages: Lists.append(state.messages, message),
        status: :idle,
        streaming_message: nil
    }
  end

  defp reduce(state, %Event{type: :assistant_stream_started, at: at}) do
    %{
      state
      | streaming_message: %{role: :assistant, text: "", thinking: "", at: at},
        status: :working
    }
  end

  defp reduce(state, %Event{type: :assistant_delta, data: %{text: text}}) do
    update_streaming(state, :text, text)
  end

  defp reduce(state, %Event{type: :assistant_thinking_delta, data: %{text: text}}) do
    update_streaming(state, :thinking, text)
  end

  defp reduce(state, %Event{type: :assistant_stream_finished, at: at}) do
    message = Map.put(state.streaming_message || %{role: :assistant, text: "", at: at}, :at, at)

    %{
      state
      | messages: Lists.append(state.messages, message),
        streaming_message: nil,
        status: :idle
    }
  end

  defp reduce(state, %Event{type: :assistant_aborted, data: data}) do
    notice = %{level: :warning, text: Map.get(data, :reason, "stream aborted")}

    %{
      state
      | notifications: Lists.append(state.notifications, notice),
        streaming_message: nil,
        status: :idle
    }
  end

  defp reduce(state, %Event{type: :tool_started, data: %{id: id} = data}) do
    tool = data |> Map.put_new(:status, :running) |> Map.put_new(:expanded?, false)
    %{state | pending_tools: Map.put(state.pending_tools, id, tool), status: :working}
  end

  defp reduce(state, %Event{type: :tool_finished, data: %{id: id} = data}) do
    pending_tools = Map.update(state.pending_tools, id, data, &Map.merge(&1, data))
    %{state | pending_tools: pending_tools}
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
    %{state | usage: Usage.summarize([state.usage, usage])}
  end

  defp reduce(state, %Event{type: :status_changed, data: %{status: status}}) do
    %{state | status: status}
  end

  defp reduce(state, %Event{type: :overlay_opened, data: data}) do
    %{state | overlays: Lists.append(state.overlays, data)}
  end

  defp reduce(state, %Event{type: :overlay_closed}) do
    %{state | overlays: Enum.drop(state.overlays, -1)}
  end

  defp reduce(state, %Event{type: :notification_added, data: data}) do
    %{state | notifications: Lists.append(state.notifications, data)}
  end

  defp reduce(state, %Event{type: :notification_expired, data: %{id: id}}) do
    %{state | notifications: Enum.reject(state.notifications, &(&1[:id] == id || &1["id"] == id))}
  end

  defp reduce(state, %Event{type: :plugin_status_updated, data: %{key: key, text: text}}) do
    %{state | plugin_statuses: Map.put(state.plugin_statuses, key, text)}
  end

  defp reduce(state, %Event{type: :plugin_status_cleared, data: %{key: key}}) do
    %{state | plugin_statuses: Map.delete(state.plugin_statuses, key)}
  end

  defp reduce(state, %Event{type: :plugin_widget_updated, data: %{key: key} = data}) do
    %{state | plugin_widgets: Map.put(state.plugin_widgets, key, Map.delete(data, :key))}
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
    selector = data |> Map.put_new(:selected, 0) |> Map.put_new(:items, [])

    %{
      state
      | selector: selector,
        overlays: Lists.append(state.overlays, Map.put(selector, :kind, :selector))
    }
  end

  defp reduce(state, %Event{type: :selector_moved, data: %{direction: direction}}) do
    %{
      state
      | selector: move_selector(state.selector, direction),
        overlays: update_selector_overlay(state.overlays, direction)
    }
  end

  defp reduce(state, %Event{type: :selector_closed}) do
    %{
      state
      | selector: nil,
        overlays: Enum.reject(state.overlays, &(&1[:kind] == :selector || &1.kind == :selector))
    }
  end

  defp reduce(state, %Event{type: :selector_confirmed}) do
    %{
      state
      | selector: nil,
        overlays: Enum.reject(state.overlays, &(&1[:kind] == :selector || &1.kind == :selector))
    }
  end

  defp reduce(state, _event), do: state

  defp move_selector(nil, _direction), do: nil

  defp move_selector(selector, direction) do
    count = length(Map.get(selector, :items, []))
    selected = Map.get(selector, :selected, 0)
    Map.put(selector, :selected, clamp_selection(selected + direction, count))
  end

  defp update_selector_overlay(overlays, direction) do
    Enum.map(overlays, fn
      %{kind: :selector} = overlay -> move_selector(overlay, direction)
      overlay -> overlay
    end)
  end

  defp clamp_selection(_selected, 0), do: 0
  defp clamp_selection(selected, count), do: selected |> max(0) |> min(count - 1)

  defp update_streaming(state, key, delta) do
    message = state.streaming_message || %{role: :assistant, text: "", thinking: ""}
    updated = Map.update(message, key, delta, &(&1 <> delta))
    %{state | streaming_message: updated, status: :working}
  end
end
