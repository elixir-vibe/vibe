defmodule Exy.Repo.Migrations.CreateStorageTables do
  use Ecto.Migration

  def change do
    Exy.Storage.Migrations.CreateStorageTables.change()
  end
end
