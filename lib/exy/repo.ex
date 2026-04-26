defmodule Exy.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :exy,
    adapter: Ecto.Adapters.SQLite3
end
