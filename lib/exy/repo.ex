defmodule Exy.Repo do
  @moduledoc "Internal implementation module."
  use Ecto.Repo,
    otp_app: :exy,
    adapter: Ecto.Adapters.SQLite3
end
