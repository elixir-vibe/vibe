defmodule Vibe.Session.Replay do
  @moduledoc "Restores and replays persisted session events."

  alias Vibe.UI.Reducer

  @spec restore_state(Vibe.UI.State.t(), boolean(), boolean()) ::
          {Vibe.UI.State.t(), non_neg_integer(), list()}
  def restore_state(state, false, _restoring?), do: {state, 0, []}

  def restore_state(state, true, restoring?) do
    events = Vibe.Session.Store.session_events(state.session_id)

    session_state =
      state
      |> Reducer.apply_events(Enum.map(events, fn {_seq, event} -> event end))
      |> finalize_restored_state(restoring?)

    event_seq = events |> last_event({0, nil}) |> elem(0)
    {session_state, event_seq, Enum.take(events, -200)}
  end

  @spec replay_events(map(), non_neg_integer(), pid()) :: :ok
  def replay_events(state, replay_after, pid) when is_pid(pid) do
    events =
      if durable_replay?(state, replay_after) do
        Vibe.Session.Store.session_events_after(state.state.session_id, replay_after)
      else
        Enum.filter(state.events_tail, fn {seq, _event} -> seq > replay_after end)
      end

    Enum.each(events, fn {_seq, event} -> send(pid, {Vibe.Session, :event, event}) end)
  end

  defp finalize_restored_state(state, false), do: state

  defp finalize_restored_state(%{status: :working} = state, true) do
    has_active_stream? = not is_nil(state.streaming_message)

    has_running_tool? =
      Enum.any?(state.pending_tools, fn {_id, tool} -> Map.get(tool, :status) == :running end)

    if has_active_stream? or has_running_tool?, do: state, else: %{state | status: :idle}
  end

  defp finalize_restored_state(state, true), do: state

  defp durable_replay?(%{persist?: false}, _replay_after), do: false
  defp durable_replay?(%{events_tail: []}, _replay_after), do: false

  defp durable_replay?(%{events_tail: [{oldest_seq, _event} | _events]}, replay_after),
    do: replay_after < oldest_seq

  defp last_event([], default), do: default
  defp last_event([event], _default), do: event
  defp last_event([_event | events], default), do: last_event(events, default)
end
