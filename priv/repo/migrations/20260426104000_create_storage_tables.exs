defmodule Vibe.Repo.Migrations.CreateStorageTables do
  use Ecto.Migration

  def change do
    Vibe.Storage.Migrations.CreateStorageTables.change()
  end
end
