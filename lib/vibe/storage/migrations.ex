defmodule Vibe.Storage.Migrations do
  @moduledoc "Ecto migration runner for the local SQLite database."
  @create_storage_tables_version 20_260_522_001_000
  @create_fts_indexes_version 20_260_522_002_000
  @create_goals_version 20_260_522_003_000

  @migrations [
    {@create_storage_tables_version, Vibe.Storage.Migrations.CreateStorageTables},
    {@create_fts_indexes_version, Vibe.Storage.Migrations.CreateFTSIndexes},
    {@create_goals_version, Vibe.Storage.Migrations.CreateGoals}
  ]

  @spec versions() :: [non_neg_integer()]
  def versions, do: Enum.map(@migrations, &elem(&1, 0))

  @spec latest_version() :: non_neg_integer()
  def latest_version, do: @migrations |> List.last() |> elem(0)

  @spec run(Ecto.Repo.t()) :: :ok
  def run(repo) do
    Enum.each(@migrations, fn {version, migration} ->
      Ecto.Migrator.up(repo, version, migration, log: false)
    end)
  end
end
