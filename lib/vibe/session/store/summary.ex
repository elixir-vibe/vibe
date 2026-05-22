defmodule Vibe.Session.Store.Summary do
  @moduledoc "Session summary extraction for dashboards and previews."
  alias Vibe.Session.Store.EventLog
  alias Vibe.Storage.Schema.Session
  alias Vibe.UI.{Reducer, State}

  @spec refresh(String.t(), (-> [{non_neg_integer(), Vibe.Event.t()}])) :: :ok
  def refresh(session_id, fallback \\ fn -> [] end) do
    case summary(session_id, fallback) do
      nil -> update_empty(session_id)
      summary -> update_summary(session_id, summary)
    end
  end

  @spec summary(String.t(), (-> [{non_neg_integer(), Vibe.Event.t()}])) :: map() | nil
  def summary(session_id, fallback \\ fn -> [] end) do
    events = EventLog.session_events(session_id, fallback)

    if events == [] do
      nil
    else
      state = session_id |> restore_state(events) |> finalize_restored_state()
      messages = conversation_messages(state.messages)
      first_user = Enum.find(messages, &(&1[:role] == :user))
      last_message = last_message(messages)

      %{
        status: state.status,
        model: state.model,
        message_count: length(messages),
        first_message: Vibe.Session.Preview.message(first_user),
        last_message_preview: Vibe.Session.Preview.message(last_message),
        usage: state.usage
      }
    end
  end

  defp update_empty(session_id) do
    case Vibe.Repo.get(Session, session_id) do
      nil ->
        :ok

      session ->
        session |> Ecto.Changeset.change(%{message_count: 0}) |> Vibe.Repo.update!() |> ok()
    end
  end

  defp update_summary(session_id, summary) do
    session = Vibe.Repo.get!(Session, session_id)

    session
    |> Ecto.Changeset.change(%{
      status: to_string(summary.status || :idle),
      model: summary.model,
      message_count: summary.message_count,
      first_message_preview: summary.first_message,
      last_message_preview: summary.last_message_preview,
      usage_input_tokens: get_in(summary.usage, [:input_tokens]) || 0,
      usage_output_tokens: get_in(summary.usage, [:output_tokens]) || 0,
      usage_total_tokens: get_in(summary.usage, [:total_tokens]) || 0,
      usage_total_cost: get_in(summary.usage, [:total_cost]) || 0.0
    })
    |> Vibe.Repo.update!()
    |> ok()
  end

  defp finalize_restored_state(%{status: :working} = state) do
    has_active_stream? = not is_nil(state.streaming_message)

    has_running_tool? =
      Enum.any?(state.pending_tools, fn {_id, tool} -> Map.get(tool, :status) == :running end)

    if has_active_stream? or has_running_tool?, do: state, else: %{state | status: :idle}
  end

  defp finalize_restored_state(state), do: state

  defp conversation_messages(messages) do
    Enum.reject(messages, fn message ->
      match?(%{streaming?: true}, message) or message[:role] == :system
    end)
  end

  defp last_message([]), do: nil
  defp last_message([message]), do: message
  defp last_message([_message | messages]), do: last_message(messages)

  defp restore_state(session_id, events) do
    events
    |> Enum.map(fn {_seq, event} -> event end)
    |> then(&Reducer.apply_events(State.new(session_id: session_id), &1))
  end

  defp ok(_result), do: :ok
end
