defmodule Exy.Storage do
  @moduledoc "SQLite-backed durable state: sessions, events, memory, telemetry."
  @sqlite_busy_timeout_ms 5_000

  @schemas [
    sessions: Exy.Storage.Schema.Session,
    ui_events: Exy.Storage.Schema.UIEvent,
    trajectory_events: Exy.Storage.Schema.TrajectoryEvent,
    eval_states: Exy.Storage.Schema.EvalState,
    subagent_jobs: Exy.Storage.Schema.SubagentJob,
    subagent_schedules: Exy.Storage.Schema.SubagentSchedule,
    memories: Exy.Storage.Schema.Memory,
    telemetry_events: Exy.Storage.Schema.TelemetryEvent,
    imports: Exy.Storage.Schema.Import
  ]

  @spec configure_repo() :: :ok
  def configure_repo do
    database = Exy.Paths.database() |> Path.expand()
    File.mkdir_p!(Path.dirname(database))

    current = Application.get_env(:exy, Exy.Repo, [])

    Application.put_env(
      :exy,
      Exy.Repo,
      current
      |> Keyword.put(:database, database)
      |> Keyword.put_new(:journal_mode, :wal)
      |> Keyword.put_new(:busy_timeout, @sqlite_busy_timeout_ms)
      |> Keyword.put_new(:pool_size, 1)
      |> Keyword.put_new(:log, false)
    )

    :ok
  end

  @spec ready?() :: boolean()
  def ready? do
    ensure_repo_started!()

    applied_versions =
      Exy.Repo
      |> Ecto.Migrator.migrations()
      |> Enum.flat_map(fn
        {:up, version, _name} -> [version]
        _migration -> []
      end)

    Enum.all?(Exy.Storage.Migrations.versions(), &(&1 in applied_versions))
  rescue
    _exception -> false
  end

  @spec ensure!() :: :ok
  def ensure! do
    :global.trans({__MODULE__, :migration}, fn ->
      cond do
        :persistent_term.get({__MODULE__, :migrated}, false) ->
          :ok

        ready?() ->
          :persistent_term.put({__MODULE__, :migrated}, true)
          :ok

        true ->
          migrate!()
          :persistent_term.put({__MODULE__, :migrated}, true)
          :ok
      end
    end)
  end

  @spec migrate!() :: :ok
  def migrate! do
    configure_repo()

    {:ok, _repo, _migration_result} =
      Ecto.Migrator.with_repo(Exy.Repo, fn repo ->
        Exy.Storage.Migrations.run(repo)
      end)

    :ok
  rescue
    Ecto.ConstraintError ->
      :ok
  end

  @spec normalize_datetime(DateTime.t() | nil) :: DateTime.t() | nil
  def normalize_datetime(nil), do: nil

  def normalize_datetime(%DateTime{} = datetime),
    do: datetime |> DateTime.to_unix(:microsecond) |> DateTime.from_unix!(:microsecond)

  @spec checkpoint!() :: :ok
  def checkpoint! do
    ensure!()
    Ecto.Adapters.SQL.query!(Exy.Repo, "PRAGMA wal_checkpoint(TRUNCATE)", [])
    :ok
  end

  @spec vacuum!() :: :ok
  def vacuum! do
    ensure!()
    Ecto.Adapters.SQL.query!(Exy.Repo, "VACUUM", [])
    checkpoint!()
  end

  @spec status() :: map()
  def status do
    ensure!()

    counts =
      Map.new(@schemas, fn {table, schema} ->
        {Atom.to_string(table), Exy.Repo.aggregate(schema, :count)}
      end)

    %{database: Exy.Paths.database() |> Path.expand(), tables: counts}
  end

  defp ensure_repo_started! do
    configure_repo()

    case Process.whereis(Exy.Repo) do
      nil ->
        {:ok, _apps} = Application.ensure_all_started(:ecto_sqlite3)

        case Exy.Repo.start_link() do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

      _pid ->
        :ok
    end
  end
end
