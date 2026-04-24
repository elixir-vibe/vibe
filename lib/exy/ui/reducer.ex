defmodule Exy.UI.Reducer do
  @moduledoc """
  Pure reducer for Exy's UI-neutral event stream.
  """

  alias Exy.LLM.Usage
  alias Exy.UI.{Event, State}

  @spec apply_event(State.t(), Event.t()) :: State.t()
  def apply_event(%State{} = state, %Event{} = event) do
    state
    |> Map.update!(:events, &(&1 ++ [event]))
    |> reduce(event)
  end

  @spec apply_events(State.t(), [Event.t()]) :: State.t()
  def apply_events(%State{} = state, events), do: Enum.reduce(events, state, &apply_event(&2, &1))

  defp reduce(state, %Event{type: :user_message_added, at: at, data: data}) do
    message = %{role: :user, text: Map.fetch!(data, :text), at: at}
    %{state | messages: state.messages ++ [message], status: :working}
  end

  defp reduce(state, %Event{type: :assistant_message_added, at: at, data: data}) do
    message = Map.merge(%{role: :assistant, at: at}, data)
    %{state | messages: state.messages ++ [message], status: :idle}
  end

  defp reduce(state, %Event{type: :tool_started, data: %{id: id} = data}) do
    tool = data |> Map.put_new(:status, :running) |> Map.put_new(:expanded?, false)
    %{state | pending_tools: Map.put(state.pending_tools, id, tool), status: :working}
  end

  defp reduce(state, %Event{type: :tool_finished, data: %{id: id} = data}) do
    pending_tools = Map.update(state.pending_tools, id, data, &Map.merge(&1, data))
    %{state | pending_tools: pending_tools}
  end

  defp reduce(state, %Event{type: :usage_updated, data: usage}) do
    %{state | usage: Usage.summarize([state.usage, usage])}
  end

  defp reduce(state, %Event{type: :status_changed, data: %{status: status}}) do
    %{state | status: status}
  end

  defp reduce(state, %Event{type: :overlay_opened, data: data}) do
    %{state | overlays: state.overlays ++ [data]}
  end

  defp reduce(state, %Event{type: :overlay_closed}) do
    %{state | overlays: Enum.drop(state.overlays, -1)}
  end

  defp reduce(state, _event), do: state
end
