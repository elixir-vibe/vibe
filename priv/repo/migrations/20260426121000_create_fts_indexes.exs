defmodule Exy.Repo.Migrations.CreateFTSIndexes do
  use Ecto.Migration

  def up do
    Exy.Storage.Migrations.CreateFTSIndexes.up()
  end

  def down do
    Exy.Storage.Migrations.CreateFTSIndexes.down()
  end
end
