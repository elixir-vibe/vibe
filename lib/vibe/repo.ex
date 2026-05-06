defmodule Vibe.Repo do
  @moduledoc "Ecto repo for the local SQLite database."
  use Ecto.Repo,
    otp_app: :vibe,
    adapter: Ecto.Adapters.SQLite3
end
