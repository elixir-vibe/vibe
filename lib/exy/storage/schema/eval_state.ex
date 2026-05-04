defmodule Exy.Storage.Schema.EvalState do
  @moduledoc "Ecto schema: persisted eval session state snapshots."
  use Ecto.Schema

  @primary_key {:session_id, :string, autogenerate: false}
  schema "eval_states" do
    field(:state, :binary)
    field(:updated_at, :utc_datetime_usec)
  end
end
