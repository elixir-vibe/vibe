defmodule Vibe.Session.Listing do
  @moduledoc "Session list queries combining live processes and stored records."

  alias Vibe.Session.Store
  @spec active_count() :: non_neg_integer()
  def active_count do
    Registry.select(Vibe.Registry, [{{{:session, :"$1"}, :"$2", :"$3"}, [], [true]}])
    |> length()
  end

  @spec list(keyword()) :: [map()]
  def list(opts \\ []) do
    current_state = Keyword.get(opts, :current_state)

    live =
      Registry.select(Vibe.Registry, [
        {{{:session, :"$1"}, :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}
      ])
      |> Enum.map(&live_info(&1, current_state))

    stored = Store.list() |> Enum.map(&Map.put(&1, :live?, false))
    live_ids = MapSet.new(Enum.map(live, & &1.id))

    (live ++ Enum.reject(stored, &MapSet.member?(live_ids, &1.id)))
    |> Enum.reject(&empty_session?/1)
    |> Enum.sort_by(&updated_at_sort_key/1, :desc)
  end

  @spec start_stored(String.t()) :: {:ok, pid()} | {:error, :not_found}
  def start_stored(id) do
    if stored?(id),
      do: Vibe.Session.start(session_id: id, restoring?: true),
      else: {:error, :not_found}
  end

  @spec via(String.t()) :: {:via, Registry, {Vibe.Registry, {:session, String.t()}}}
  def via(id), do: {:via, Registry, {Vibe.Registry, {:session, id}}}

  defp updated_at_sort_key(%{updated_at: %DateTime{} = updated_at}),
    do: DateTime.to_unix(updated_at, :microsecond)

  defp updated_at_sort_key(_session), do: 0

  defp live_info({id, pid}, current_state) do
    state = live_state(id, pid, current_state)
    stored = Store.info(id) || %{id: id}

    stored
    |> Map.merge(%{
      id: id,
      live?: true,
      status: state.status,
      model: state.model,
      message_count: length(conversation_messages(state.messages)),
      last_message_preview:
        state.messages |> conversation_messages() |> List.last() |> Vibe.Session.Preview.message(),
      usage: state.usage
    })
  end

  defp live_state(id, pid, %{session_id: id} = state) when pid == self(), do: state
  defp live_state(_id, pid, _current_state), do: Vibe.Session.state(pid)

  defp conversation_messages(messages) do
    Enum.reject(messages, fn message ->
      match?(%{streaming?: true}, message) or message[:role] == :system
    end)
  end

  defp empty_session?(%{message_count: count}) when is_integer(count), do: count == 0
  defp empty_session?(_session), do: false

  defp stored?(id) do
    not is_nil(Store.info(id)) or File.exists?(Store.path(id)) or
      File.exists?(Store.ui_events_path(id))
  end
end
