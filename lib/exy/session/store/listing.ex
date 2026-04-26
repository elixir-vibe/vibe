defmodule Exy.Session.Store.Listing do
  @moduledoc false

  import Ecto.Query

  alias Exy.Storage.Schema.Session
  alias Exy.UI.{Reducer, State}

  @spec info(String.t()) :: map() | nil
  def info(session_id) when is_binary(session_id) do
    Exy.Storage.ensure!()

    case Exy.Repo.get(Session, session_id) do
      %Session{} = session -> session_info(session)
      nil -> nil
    end
  end

  @spec list() :: [map()]
  def list do
    Exy.Storage.ensure!()

    Session
    |> order_by([session], desc: session.updated_at)
    |> Exy.Repo.all()
    |> Enum.map(&session_info/1)
  end

  @spec summary(String.t()) :: map() | nil
  def summary(session_id) do
    events = Exy.Session.Store.ui_events(session_id)

    if events == [] do
      nil
    else
      state = session_id |> restore_state(events) |> finalize_restored_state()
      messages = Enum.reject(state.messages, &match?(%{streaming?: true}, &1))
      first_user = Enum.find(messages, &(&1[:role] == :user))
      last_message = List.last(messages)

      %{
        status: state.status,
        model: state.model,
        message_count: length(messages),
        first_message: Exy.Session.Preview.message(first_user),
        last_message_preview: Exy.Session.Preview.message(last_message),
        usage: state.usage
      }
    end
  end

  defp session_info(%Session{} = session) do
    %{
      id: session.id,
      path: Exy.Paths.database() |> Path.expand(),
      size: 0,
      created_at: nil,
      updated_at: session.updated_at,
      cwd: session.cwd,
      message_count: session.message_count || 0,
      first_message: session.first_message_preview,
      last_message_preview: session.last_message_preview,
      status: status_atom(session.status),
      model: session.model,
      usage: %{
        input_tokens: session.usage_input_tokens || 0,
        output_tokens: session.usage_output_tokens || 0,
        total_tokens: session.usage_total_tokens || 0,
        total_cost: session.usage_total_cost || 0.0
      }
    }
  end

  defp finalize_restored_state(%{status: :working} = state) do
    has_active_stream? = not is_nil(state.streaming_message)

    has_running_tool? =
      Enum.any?(state.pending_tools, fn {_id, tool} -> Map.get(tool, :status) == :running end)

    if has_active_stream? or has_running_tool?, do: state, else: %{state | status: :idle}
  end

  defp finalize_restored_state(state), do: state

  defp restore_state(session_id, events) do
    events
    |> Enum.map(fn {_seq, event} -> event end)
    |> then(&Reducer.apply_events(State.new(session_id: session_id), &1))
  end

  defp status_atom(status) when is_binary(status) do
    String.to_existing_atom(status)
  rescue
    ArgumentError -> :idle
  end

  defp status_atom(status) when is_atom(status), do: status
  defp status_atom(_status), do: :idle
end
