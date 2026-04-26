defmodule Exy.Session.Store do
  @moduledoc """
  Durable SQLite-backed sessions for dialogs, tool events, eval state, and usage.
  """

  import Ecto.Query

  alias Exy.Session.Store.{Codec, Listing}
  alias Exy.Storage.Schema.{EvalState, Session, TrajectoryEvent, UIEvent}
  alias Exy.Trajectory
  alias Exy.UI.Event

  @spec new_id() :: String.t()
  def new_id do
    now = DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S")
    suffix = 6 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    now <> "-" <> suffix
  end

  @spec dir() :: String.t()
  def dir do
    Exy.Paths.sessions_dir()
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
    Exy.Storage.ensure!()
    ensure_session(event.session_id, event.at)
    encoded = Codec.encode_trajectory(event)

    %TrajectoryEvent{}
    |> Map.merge(%{
      session_id: event.session_id,
      event_id: event.id,
      type: Atom.to_string(event.type),
      at: Exy.Storage.normalize_datetime(event.at),
      data: encoded["data"]
    })
    |> Exy.Repo.insert(on_conflict: :nothing, conflict_target: :event_id)
    |> case do
      {:ok, _event} ->
        refresh_session_summary(event.session_id)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec events(String.t()) :: [Trajectory.t()]
  def events(session_id) when is_binary(session_id) do
    Exy.Storage.ensure!()

    TrajectoryEvent
    |> where([event], event.session_id == ^session_id)
    |> order_by([event], [event.at, event.id])
    |> Exy.Repo.all()
    |> Enum.flat_map(&decode_trajectory_record/1)
  end

  @spec all_events() :: [Trajectory.t()]
  def all_events do
    Exy.Storage.ensure!()

    TrajectoryEvent
    |> order_by([event], [event.at, event.id])
    |> Exy.Repo.all()
    |> Enum.flat_map(&decode_trajectory_record/1)
  end

  @spec clear() :: :ok
  def clear do
    Exy.Storage.ensure!()

    Enum.each(
      [
        Exy.Storage.Schema.UIEventFTS,
        Exy.Storage.Schema.MemoryFTS,
        UIEvent,
        TrajectoryEvent,
        EvalState,
        Exy.Storage.Schema.SubagentJob,
        Exy.Storage.Schema.SubagentSchedule,
        Exy.Storage.Schema.Memory,
        Exy.Storage.Schema.TelemetryEvent,
        Session
      ],
      &Exy.Repo.delete_all/1
    )

    :ok
  end

  @spec append_eval_state(Code.binding(), Macro.Env.t(), keyword()) :: :ok | {:error, term()}
  def append_eval_state(binding, %Macro.Env{} = env, opts) when is_list(binding) do
    session_id = Keyword.fetch!(opts, :session_id)
    Exy.Storage.ensure!()
    now = DateTime.utc_now() |> Exy.Storage.normalize_datetime()
    ensure_session(session_id, now)
    snapshot = :erlang.term_to_binary(%{binding: binding, env: env})

    %EvalState{session_id: session_id, state: snapshot, updated_at: now}
    |> Exy.Repo.insert(
      on_conflict: [set: [state: snapshot, updated_at: now]],
      conflict_target: :session_id
    )
    |> ok()
  end

  @spec eval_state(String.t()) :: %{binding: Code.binding(), env: Macro.Env.t()} | nil
  def eval_state(session_id) when is_binary(session_id) do
    Exy.Storage.ensure!()

    case Exy.Repo.get(EvalState, session_id) do
      %EvalState{state: state} ->
        case Codec.decode_eval_state_binary(state) do
          {:ok, decoded} -> decoded
          :error -> nil
        end

      nil ->
        nil
    end
  end

  @spec append_ui_event(Event.t(), non_neg_integer()) :: :ok | {:error, term()}
  def append_ui_event(%Event{} = event, seq) do
    Exy.Storage.ensure!()
    ensure_session(event.session_id, event.at)

    %UIEvent{}
    |> Map.merge(ui_event_row(event, seq))
    |> Exy.Repo.insert(
      on_conflict: {:replace, [:event_id, :type, :at, :data]},
      conflict_target: [:session_id, :seq]
    )
    |> case do
      {:ok, stored_event} ->
        Exy.Storage.FTS.index_ui_event(stored_event)
        refresh_session_summary(event.session_id)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec append_ui_events([{non_neg_integer(), Event.t()}]) :: :ok | {:error, term()}
  def append_ui_events([]), do: :ok

  def append_ui_events([{_seq, %Event{} = first_event} | _rest] = events) do
    Exy.Storage.ensure!()
    ensure_session(first_event.session_id, first_event.at)

    rows = Enum.map(events, fn {seq, event} -> ui_event_row(event, seq) end)

    result =
      Exy.Repo.transaction(fn ->
        rows
        |> Enum.chunk_every(500)
        |> Enum.each(fn chunk ->
          Exy.Repo.insert_all(UIEvent, chunk,
            on_conflict: {:replace, [:event_id, :type, :at, :data]},
            conflict_target: [:session_id, :seq]
          )
        end)

        Exy.Storage.FTS.index_ui_event_rows(rows)
        refresh_session_summary(first_event.session_id)
      end)

    case result do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec ui_events(String.t()) :: [{non_neg_integer(), Event.t()}]
  def ui_events(session_id) when is_binary(session_id) do
    Exy.Storage.ensure!()

    events =
      UIEvent
      |> where([event], event.session_id == ^session_id)
      |> order_by([event], event.seq)
      |> Exy.Repo.all()
      |> Enum.flat_map(&decode_ui_event_record/1)

    case events do
      [] -> session_id |> events() |> Codec.project_trajectory_events()
      events -> events
    end
  end

  @spec ui_events_after(String.t(), non_neg_integer()) :: [{non_neg_integer(), Event.t()}]
  def ui_events_after(session_id, seq) when is_binary(session_id) and is_integer(seq) do
    Exy.Storage.ensure!()

    UIEvent
    |> where([event], event.session_id == ^session_id and event.seq > ^seq)
    |> order_by([event], event.seq)
    |> Exy.Repo.all()
    |> Enum.flat_map(&decode_ui_event_record/1)
  end

  @spec info(String.t()) :: map() | nil
  def info(session_id) when is_binary(session_id), do: Listing.info(session_id)

  @spec list() :: [map()]
  def list, do: Listing.list()

  @spec ensure_session(String.t(), DateTime.t()) :: :ok
  def ensure_session(session_id, at \\ DateTime.utc_now()) do
    Exy.Storage.ensure!()
    at = Exy.Storage.normalize_datetime(at)

    %Session{id: session_id, started_at: at, updated_at: at}
    |> Exy.Repo.insert(
      on_conflict: [set: [updated_at: at]],
      conflict_target: :id
    )

    :ok
  end

  defp ui_event_row(%Event{} = event, seq) do
    encoded = Codec.encode_ui_event(event, seq)

    %{
      session_id: event.session_id,
      seq: seq,
      event_id: event.id,
      type: Atom.to_string(event.type),
      at: Exy.Storage.normalize_datetime(event.at),
      data: encoded["data"]
    }
  end

  defp refresh_session_summary(session_id) do
    case Listing.summary(session_id) do
      nil ->
        :ok

      summary ->
        session = Exy.Repo.get!(Session, session_id)

        Ecto.Changeset.change(session, %{
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
        |> Exy.Repo.update!()

        :ok
    end
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
    |> Codec.decode_ui_event_map()
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
    |> Codec.decode_trajectory_map()
    |> case do
      {:ok, event} -> [event]
      :error -> []
    end
  end

  defp ok({:ok, _result}), do: :ok
  defp ok({:error, reason}), do: {:error, reason}

  defp safe_session_id(session_id) do
    String.replace(session_id, ~r/[^A-Za-z0-9_.-]/, "-")
  end
end
