defmodule Vibe.Storage.Search do
  @moduledoc """
  Local FTS search over Vibe sessions and curated memory.

  Search uses SQLite FTS indexes managed by `Vibe.Storage.FTS`. Results are
  returned as structured `Vibe.Storage.Search.Result` values so eval, CLI, TUI,
  and future web clients can render the same semantic data.
  """
  import Ecto.Query

  alias Vibe.Storage.Schema.{MemoryFTS, Session, UIEventFTS}
  alias Vibe.Storage.Search.Result

  @spec query(String.t(), keyword()) :: {:ok, [Result.t()]} | {:error, term()}
  def query(query, opts \\ []) when is_binary(query) and is_list(opts) do
    Vibe.Storage.ensure!()

    fts_query = Vibe.Storage.FTS.plain_query(query)

    if fts_query == "" do
      {:ok, []}
    else
      sources = Keyword.get(opts, :scopes, [:sessions, :memory])
      limit = Keyword.get(opts, :limit, 10)

      results =
        []
        |> maybe_search_sessions(fts_query, sources, opts)
        |> maybe_search_memories(fts_query, sources, opts)
        |> Enum.sort_by(&rank_sort_key/1)
        |> Enum.take(limit)

      {:ok, results}
    end
  rescue
    exception -> {:error, exception}
  end

  @spec sessions(String.t(), keyword()) :: [Result.t()]
  def sessions(query, opts \\ []) do
    Vibe.Storage.ensure!()
    fts_query = Vibe.Storage.FTS.plain_query(query)

    if fts_query == "" do
      []
    else
      search_sessions(fts_query, opts)
    end
  end

  @spec memories(String.t(), keyword()) :: [Result.t()]
  def memories(query, opts \\ []) do
    Vibe.Storage.ensure!()
    fts_query = Vibe.Storage.FTS.plain_query(query)

    if fts_query == "" do
      []
    else
      search_memories(fts_query, opts)
    end
  end

  defp maybe_search_sessions(results, fts_query, sources, opts) do
    if :sessions in sources or :session in sources do
      results ++ search_sessions(fts_query, opts)
    else
      results
    end
  end

  defp maybe_search_memories(results, fts_query, sources, opts) do
    if :memory in sources or :memories in sources do
      results ++ search_memories(fts_query, opts)
    else
      results
    end
  end

  defp search_sessions(fts_query, opts) do
    limit = Keyword.get(opts, :limit, 10)
    session_id = Keyword.get(opts, :session_id)
    exclude_session_id = Keyword.get(opts, :exclude_session_id)
    cwd = Keyword.get(opts, :cwd)

    roles =
      opts
      |> Keyword.get(:roles, default_roles(opts))
      |> Enum.map(&to_string/1)

    UIEventFTS
    |> join(:inner, [row], session in Session, on: session.id == row.session_id)
    |> where([row, _session], fragment("ui_events_fts MATCH ?", ^fts_query))
    |> where([row, _session], row.role in ^roles)
    |> where_session(session_id)
    |> where_not_session(exclude_session_id)
    |> where_cwd(cwd)
    |> order_by([row, _session], fragment("bm25(ui_events_fts)"))
    |> limit(^limit)
    |> select([row, session], %{
      session_id: row.session_id,
      event_id: row.event_id,
      seq: row.seq,
      role: row.role,
      cwd: session.cwd,
      at: row.at,
      text: row.text,
      rank: fragment("bm25(ui_events_fts)"),
      snippet: fragment("snippet(ui_events_fts, 5, ?, ?, ?, ?)", "<mark>", "</mark>", "…", 32)
    })
    |> Vibe.Repo.all()
    |> Enum.map(&session_result/1)
  end

  defp search_memories(fts_query, opts) do
    limit = Keyword.get(opts, :limit, 10)
    scopes = Keyword.get(opts, :memory_scopes, Keyword.get(opts, :scopes, [:user, :global]))
    encoded_scopes = Enum.map(scopes, &encode_scope/1)

    MemoryFTS
    |> where([row], fragment("memories_fts MATCH ?", ^fts_query))
    |> where_memory_scopes(encoded_scopes)
    |> order_by([row], fragment("bm25(memories_fts)"))
    |> limit(^limit)
    |> select([row], %{
      memory_id: row.memory_id,
      scope_type: row.scope_type,
      scope_id: row.scope_id,
      inserted_at: row.inserted_at,
      text: row.text,
      rank: fragment("bm25(memories_fts)"),
      snippet: fragment("snippet(memories_fts, 4, ?, ?, ?, ?)", "<mark>", "</mark>", "…", 32)
    })
    |> Vibe.Repo.all()
    |> Enum.map(&memory_result/1)
  end

  defp default_roles(opts) do
    if Keyword.get(opts, :include_tools, false),
      do: [:user, :assistant, :tool],
      else: [:user, :assistant]
  end

  defp where_session(query, nil), do: query

  defp where_session(query, session_id),
    do: where(query, [row, _session], row.session_id == ^session_id)

  defp where_not_session(query, nil), do: query

  defp where_not_session(query, session_id),
    do: where(query, [row, _session], row.session_id != ^session_id)

  defp where_cwd(query, nil), do: query
  defp where_cwd(query, cwd), do: where(query, [_row, session], like(session.cwd, ^"%#{cwd}%"))

  defp where_memory_scopes(query, []), do: query

  defp where_memory_scopes(query, scopes) do
    Enum.reduce(scopes, dynamic(false), fn
      {scope_type, nil}, dynamic ->
        dynamic([row], ^dynamic or (row.scope_type == ^scope_type and is_nil(row.scope_id)))

      {scope_type, scope_id}, dynamic ->
        dynamic([row], ^dynamic or (row.scope_type == ^scope_type and row.scope_id == ^scope_id))
    end)
    |> then(&where(query, ^&1))
  end

  defp session_result(row) do
    %Result{
      source: :session,
      id: row.event_id,
      owner_id: row.session_id,
      title: row.cwd || "session:#{row.session_id}",
      text: row.text,
      snippet: row.snippet,
      rank: row.rank,
      at: parse_datetime(row.at),
      metadata: %{
        session_id: row.session_id,
        seq: row.seq,
        role: role_atom(row.role),
        cwd: row.cwd
      }
    }
  end

  defp memory_result(row) do
    %Result{
      source: :memory,
      id: row.memory_id,
      owner_id: format_scope(row.scope_type, row.scope_id),
      title: format_scope(row.scope_type, row.scope_id),
      text: row.text,
      snippet: row.snippet,
      rank: row.rank,
      at: parse_datetime(row.inserted_at),
      metadata: %{scope: decode_scope(row.scope_type, row.scope_id)}
    }
  end

  defp rank_sort_key(%Result{rank: rank}) when is_number(rank), do: rank
  defp rank_sort_key(_result), do: 0

  defp encode_scope(:global), do: {"global", nil}
  defp encode_scope(:user), do: {"user", nil}
  defp encode_scope({:workspace, id}), do: {"workspace", id}
  defp encode_scope({:session, id}), do: {"session", id}
  defp encode_scope({:agent, id}), do: {"agent", id}
  defp encode_scope(_scope), do: {"__none__", nil}

  defp decode_scope("global", nil), do: :global
  defp decode_scope("user", nil), do: :user
  defp decode_scope("workspace", id), do: {:workspace, id}
  defp decode_scope("session", id), do: {:session, id}
  defp decode_scope("agent", id), do: {:agent, id}

  defp format_scope(scope_type, nil), do: scope_type
  defp format_scope(scope_type, scope_id), do: "#{scope_type}:#{scope_id}"

  defp role_atom("user"), do: :user
  defp role_atom("assistant"), do: :assistant
  defp role_atom("tool"), do: :tool
  defp role_atom(role), do: role

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _invalid -> nil
    end
  end
end
