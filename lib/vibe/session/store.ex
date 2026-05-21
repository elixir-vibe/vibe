defmodule Vibe.Session.Store do
  @moduledoc """
  Durable SQLite-backed sessions for dialogs, tool events, eval state, and usage.
  """

  import Ecto.Query

  alias Vibe.Repo
  alias Vibe.Session.Store.{Listing, Summary}
  alias Vibe.Storage.Representation.SessionLog
  alias Vibe.Storage.Schema.{EvalState, Session, TrajectoryEvent, UIEvent, UIEventFTS}
  alias Vibe.Trajectory
  alias Vibe.UI.Event

  @spec new_id() :: String.t()
  def new_id do
    now = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    suffix = 6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    now <> "-" <> suffix
  end

  @spec dir() :: String.t()
  def dir do
    Vibe.Paths.sessions_dir()
    |> Path.expand()
  end

  @spec path(String.t()) :: String.t()
  def path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".jsonl")
  end

  @spec log_path(String.t()) :: String.t()
  def log_path(session_id) when is_binary(session_id) do
    Path.join(dir(), safe_session_id(session_id) <> ".log")
  end

  @spec ui_events_path(String.t()) :: String.t()
  def ui_events_path(session_id) when is_binary(session_id), do: path(session_id)

  @spec append_trajectory(atom(), map(), keyword()) :: Trajectory.t()
  def append_trajectory(type, data \\ %{}, opts \\ []) do
    event = Trajectory.new(type, data, opts)
    _ = append(event)
    event
  end

  @spec trajectory(keyword()) :: [Trajectory.t()]
  def trajectory(opts \\ []) do
    opts
    |> trajectory_events()
    |> maybe_filter_trajectory(
      Keyword.get(opts, :type),
      &(&1.type == Keyword.fetch!(opts, :type))
    )
    |> take_trajectory(Keyword.get(opts, :limit, :infinity))
  end

  @spec append(Trajectory.t()) :: :ok | {:error, term()}
  def append(%Trajectory{session_id: nil} = event),
    do: append(%{event | session_id: "__global__"})

  def append(%Trajectory{} = event) do
    Vibe.Storage.ensure!()
    ensure_session(event.session_id, event.at)
    encoded = SessionLog.encode_trajectory(event)

    %TrajectoryEvent{}
    |> Map.merge(%{
      session_id: event.session_id,
      event_id: event.id,
      type: Atom.to_string(event.type),
      at: Vibe.Storage.normalize_datetime(event.at),
      data: encoded["data"]
    })
    |> Vibe.Repo.insert(on_conflict: :nothing, conflict_target: :event_id)
    |> case do
      {:ok, _event} ->
        Summary.refresh(event.session_id)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec events(String.t()) :: [Trajectory.t()]
  def events(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()

    TrajectoryEvent
    |> where([event], event.session_id == ^session_id)
    |> order_by([event], [event.at, event.id])
    |> Vibe.Repo.all()
    |> Enum.flat_map(&decode_trajectory_record/1)
  end

  @spec all_events() :: [Trajectory.t()]
  def all_events do
    Vibe.Storage.ensure!()

    TrajectoryEvent
    |> order_by([event], [event.at, event.id])
    |> Vibe.Repo.all()
    |> Enum.flat_map(&decode_trajectory_record/1)
  end

  @spec delete(String.t()) :: :ok | {:error, :live}
  def delete(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()

    if live_session?(session_id) do
      {:error, :live}
    else
      delete_stored_session(session_id)
      :ok
    end
  end

  @spec branch(String.t(), non_neg_integer(), String.t()) :: :ok | {:error, term()}
  def branch(source_session_id, up_to_seq, branch_id) do
    events = ui_events(source_session_id)

    kept = Enum.filter(events, fn {seq, _event} -> seq <= up_to_seq end)

    if kept == [] do
      {:error, :nothing_to_branch}
    else
      branch_events =
        Enum.map(kept, fn {seq, event} ->
          {seq, %{event | session_id: branch_id}}
        end)

      ensure_session(branch_id, DateTime.utc_now())
      append_ui_events(branch_events, index?: true, refresh_summary?: true)
    end
  end

  @spec delete_many([String.t()]) :: %{deleted: [String.t()], skipped: [{String.t(), term()}]}
  def delete_many(session_ids) when is_list(session_ids) do
    Enum.reduce(session_ids, %{deleted: [], skipped: []}, fn session_id, acc ->
      case delete(session_id) do
        :ok -> %{acc | deleted: [session_id | acc.deleted]}
        {:error, reason} -> %{acc | skipped: [{session_id, reason} | acc.skipped]}
      end
    end)
    |> Map.update!(:deleted, &Enum.reverse/1)
    |> Map.update!(:skipped, &Enum.reverse/1)
  end

  @spec prune_empty() :: [String.t()]
  def prune_empty do
    Vibe.Session.Store.list()
    |> Enum.filter(fn session -> not session[:live?] and (session[:message_count] || 0) == 0 end)
    |> Enum.map(& &1.id)
    |> tap(&delete_many/1)
  end

  @spec clear() :: :ok
  def clear do
    Vibe.Storage.ensure!()

    Enum.each(
      [
        Vibe.Storage.Schema.UIEventFTS,
        Vibe.Storage.Schema.MemoryFTS,
        UIEvent,
        TrajectoryEvent,
        EvalState,
        Vibe.Storage.Schema.SubagentJob,
        Vibe.Storage.Schema.SubagentSchedule,
        Vibe.Storage.Schema.Goal,
        Vibe.Storage.Schema.Memory,
        Vibe.Storage.Schema.TelemetryEvent,
        Session
      ],
      &Vibe.Repo.delete_all/1
    )

    :ok
  end

  @spec append_eval_state(Code.binding(), Macro.Env.t(), keyword()) :: :ok | {:error, term()}
  def append_eval_state(binding, %Macro.Env{} = env, opts) when is_list(binding) do
    session_id = Keyword.fetch!(opts, :session_id)
    Vibe.Storage.ensure!()
    now = DateTime.utc_now() |> Vibe.Storage.normalize_datetime()
    ensure_session(session_id, now)
    snapshot = :erlang.term_to_binary(%{binding: binding, env: env})

    %EvalState{session_id: session_id, state: snapshot, updated_at: now}
    |> Vibe.Repo.insert(
      on_conflict: [set: [state: snapshot, updated_at: now]],
      conflict_target: :session_id
    )
    |> ok()
  end

  @spec eval_state(String.t()) :: %{binding: Code.binding(), env: Macro.Env.t()} | nil
  def eval_state(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()

    case Vibe.Repo.get(EvalState, session_id) do
      %EvalState{state: state} ->
        case SessionLog.decode_eval_state_binary(state) do
          {:ok, decoded} -> decoded
          :error -> nil
        end

      nil ->
        nil
    end
  end

  @spec append_ui_event(Event.t(), non_neg_integer()) :: :ok | {:error, term()}
  def append_ui_event(%Event{} = event, seq) do
    Vibe.Storage.ensure!()
    ensure_session(event.session_id, event.at)

    %UIEvent{}
    |> Map.merge(ui_event_row(event, seq))
    |> Vibe.Repo.insert(
      on_conflict: {:replace, [:event_id, :type, :at, :data]},
      conflict_target: [:session_id, :seq]
    )
    |> case do
      {:ok, stored_event} ->
        Vibe.Storage.FTS.index_ui_event(stored_event)
        Summary.refresh(event.session_id)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec append_ui_events([{non_neg_integer(), Event.t()}], keyword()) :: :ok | {:error, term()}
  def append_ui_events(events, opts \\ [])
  def append_ui_events([], _opts), do: :ok

  def append_ui_events([{_seq, %Event{} = first_event} | _rest] = events, opts) do
    Vibe.Storage.ensure!()
    ensure_session(first_event.session_id, first_event.at)

    rows = Enum.map(events, fn {seq, event} -> ui_event_row(event, seq) end)

    result =
      Vibe.Repo.transaction(fn ->
        rows
        |> Enum.chunk_every(500)
        |> Enum.each(fn chunk ->
          Vibe.Repo.insert_all(UIEvent, chunk,
            on_conflict: {:replace, [:event_id, :type, :at, :data]},
            conflict_target: [:session_id, :seq]
          )
        end)

        if Keyword.get(opts, :index?, true), do: Vibe.Storage.FTS.index_ui_event_rows(rows)

        if Keyword.get(opts, :refresh_summary?, true),
          do: Summary.refresh(first_event.session_id)

        :ok
      end)

    case result do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ui_events(String.t()) :: [{non_neg_integer(), Event.t()}]
  def ui_events(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()

    events =
      UIEvent
      |> where([event], event.session_id == ^session_id)
      |> order_by([event], event.seq)
      |> Vibe.Repo.all()
      |> Enum.flat_map(&decode_ui_event_record/1)

    case events do
      [] -> session_id |> events() |> SessionLog.project_trajectory_events()
      events -> events
    end
  end

  @spec ui_events_after(String.t(), non_neg_integer()) :: [{non_neg_integer(), Event.t()}]
  def ui_events_after(session_id, seq) when is_binary(session_id) and is_integer(seq) do
    Vibe.Storage.ensure!()

    UIEvent
    |> where([event], event.session_id == ^session_id and event.seq > ^seq)
    |> order_by([event], event.seq)
    |> Vibe.Repo.all()
    |> Enum.flat_map(&decode_ui_event_record/1)
  end

  @doc "Intentional facade for the public Vibe API boundary."
  @spec info(String.t()) :: map() | nil
  defdelegate info(session_id), to: Listing

  @doc "Intentional facade for the public Vibe API boundary."
  @spec list() :: [map()]
  defdelegate list, to: Listing

  @spec ensure_session(String.t(), DateTime.t(), keyword()) :: :ok
  def ensure_session(session_id, at \\ DateTime.utc_now(), attrs \\ []) do
    Vibe.Storage.ensure!()
    at = Vibe.Storage.normalize_datetime(at)
    attrs = Keyword.take(attrs, [:cwd, :model])

    %Session{}
    |> Map.merge(Map.new([id: session_id, started_at: at, updated_at: at] ++ attrs))
    |> Vibe.Repo.insert(
      on_conflict: [set: [updated_at: at] ++ present_attrs(attrs)],
      conflict_target: :id
    )

    :ok
  end

  defp present_attrs(attrs), do: Enum.reject(attrs, fn {_key, value} -> is_nil(value) end)

  defp ui_event_row(%Event{} = event, seq) do
    encoded = SessionLog.encode_ui_event(event, seq)

    %{
      session_id: event.session_id,
      seq: seq,
      event_id: event.id,
      type: Atom.to_string(event.type),
      at: Vibe.Storage.normalize_datetime(event.at),
      data: encoded["data"]
    }
  end

  defp trajectory_events(opts) do
    case Keyword.get(opts, :session_id) do
      session_id when is_binary(session_id) -> events(session_id)
      _session_id -> all_events()
    end
  end

  defp maybe_filter_trajectory(events, nil, _fun), do: events
  defp maybe_filter_trajectory(events, _value, fun), do: Enum.filter(events, fun)

  defp take_trajectory(events, :infinity), do: events
  defp take_trajectory(events, limit), do: Enum.take(events, limit)

  defp decode_ui_event_record(%UIEvent{} = event) do
    %{
      "seq" => event.seq,
      "id" => event.event_id,
      "session_id" => event.session_id,
      "type" => event.type,
      "at" => DateTime.to_iso8601(event.at),
      "data" => event.data
    }
    |> SessionLog.decode_ui_event_map()
    |> case do
      {:ok, event} -> [event]
      :error -> []
    end
  end

  defp decode_trajectory_record(%TrajectoryEvent{} = event) do
    %{
      "id" => event.event_id,
      "session_id" => event.session_id,
      "type" => event.type,
      "at" => DateTime.to_iso8601(event.at),
      "data" => event.data
    }
    |> SessionLog.decode_trajectory_map()
    |> case do
      {:ok, event} -> [event]
      :error -> []
    end
  end

  defp live_session?(session_id) do
    case Registry.lookup(Vibe.Registry, {:session, session_id}) do
      [] -> false
      _sessions -> true
    end
  end

  defp delete_stored_session(session_id) do
    Repo.delete_all(from(row in UIEventFTS, where: row.session_id == ^session_id))
    Repo.delete_all(from(row in UIEvent, where: row.session_id == ^session_id))
    Repo.delete_all(from(row in TrajectoryEvent, where: row.session_id == ^session_id))
    Repo.delete_all(from(row in EvalState, where: row.session_id == ^session_id))
    Repo.delete_all(from(row in Vibe.Storage.Schema.Goal, where: row.session_id == ^session_id))
    Repo.delete_all(from(row in Session, where: row.id == ^session_id))

    session_id |> path() |> File.rm() |> ignore_missing_file()
    session_id |> log_path() |> File.rm() |> ignore_missing_file()
    session_id |> Vibe.Files.Artifacts.session_artifact_dir() |> File.rm_rf()
  end

  defp ignore_missing_file(:ok), do: :ok
  defp ignore_missing_file({:error, :enoent}), do: :ok
  defp ignore_missing_file({:error, reason}), do: {:error, reason}

  defp ok({:ok, _result}), do: :ok
  defp ok({:error, reason}), do: {:error, reason}

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
