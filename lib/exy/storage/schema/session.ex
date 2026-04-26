defmodule Exy.Storage.Schema.Session do
  @moduledoc false

  use Ecto.Schema

  @primary_key {:id, :string, autogenerate: false}
  schema "sessions" do
    field(:cwd, :string)
    field(:model, :string)
    field(:title, :string)
    field(:status, :string, default: "idle")
    field(:started_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
    field(:ended_at, :utc_datetime_usec)
    field(:message_count, :integer, default: 0)
    field(:first_message_preview, :string)
    field(:last_message_preview, :string)
    field(:usage_input_tokens, :integer, default: 0)
    field(:usage_output_tokens, :integer, default: 0)
    field(:usage_total_tokens, :integer, default: 0)
    field(:usage_total_cost, :float, default: 0.0)
  end
end
