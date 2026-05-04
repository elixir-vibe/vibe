defmodule Exy.Repo do
  @moduledoc "Ecto repo for the local SQLite database."
  use Ecto.Repo,
    otp_app: :exy,
    adapter: Ecto.Adapters.SQLite3
end
