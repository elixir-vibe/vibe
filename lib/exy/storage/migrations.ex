defmodule Exy.Storage.Migrations do
  @moduledoc false

  @migrations [
    {20_260_426_104_000, Exy.Storage.Migrations.CreateStorageTables}
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
