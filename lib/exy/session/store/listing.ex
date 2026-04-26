defmodule Exy.Session.Store.Listing do
  @moduledoc false

  alias Exy.UI.{Event, Reducer, State}

  @spec info(String.t()) :: map() | nil
  def info(session_id) when is_binary(session_id) do
    file = safe_session_id(session_id) <> ".jsonl"
    full_path = Exy.Session.Store.path(session_id)

    if File.exists?(full_path) do
      session_info(file)
    end
  end

  @spec list() :: [map()]
  def list do
    case File.ls(Exy.Session.Store.dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
        |> Enum.reject(&String.ends_with?(&1, ".events.jsonl"))
        |> Enum.map(&session_info/1)
        |> Enum.sort_by(&DateTime.to_unix(&1.updated_at), :desc)

      {:error, _reason} ->
        []
    end
  end

  defp session_info(file) do
    full_path = Path.join(Exy.Session.Store.dir(), file)
    stat = File.stat!(full_path, time: :posix)
    id = Path.rootname(file)
    events = Exy.Session.Store.ui_events(id)
    state = id |> restore_state(events) |> finalize_restored_state()
    messages = Enum.reject(state.messages, &match?(%{streaming?: true}, &1))
    first_user = Enum.find(messages, &(&1[:role] == :user))
    last_message = List.last(messages)

    %{
      id: id,
      path: full_path,
      size: stat.size,
      created_at: created_at(events),
      updated_at: DateTime.from_unix!(stat.mtime),
      message_count: length(messages),
      first_message: Exy.Session.Preview.message(first_user),
      last_message_preview: Exy.Session.Preview.message(last_message),
      status: state.status,
      model: state.model,
      usage: state.usage
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

  defp created_at([]), do: nil
  defp created_at([{_seq, %Event{at: at}} | _events]), do: at

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
