defmodule Vibe.Repo.Migrations.CreateFTSIndexes do
  use Ecto.Migration

  def up do
    Vibe.Storage.Migrations.CreateFTSIndexes.up()
  end

  def down do
    Vibe.Storage.Migrations.CreateFTSIndexes.down()
  end
end
