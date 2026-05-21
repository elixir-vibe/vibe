defmodule Vibe.Storage.Representation.Goal do
  @moduledoc "Current storage representation for `Vibe.Goals.Goal`."

  @enforce_keys [:session_id, :goal_id, :objective, :status, :created_at, :updated_at]
  defstruct [
    :session_id,
    :goal_id,
    :objective,
    :status,
    :token_budget,
    :created_at,
    :updated_at,
    tokens_used: 0,
    time_used_seconds: 0
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          goal_id: String.t(),
          objective: String.t(),
          status: Vibe.Goals.Goal.status(),
          token_budget: pos_integer() | nil,
          tokens_used: non_neg_integer(),
          time_used_seconds: non_neg_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @spec decode!(map()) :: t()
  def decode!(%{status: status} = goal) do
    {:ok, status} = Vibe.Goals.Goal.status(status)

    %__MODULE__{
      session_id: Map.fetch!(goal, :session_id),
      goal_id: Map.fetch!(goal, :goal_id),
      objective: Map.fetch!(goal, :objective),
      status: status,
      token_budget: Map.get(goal, :token_budget),
      tokens_used: Map.get(goal, :tokens_used, 0),
      time_used_seconds: Map.get(goal, :time_used_seconds, 0),
      created_at: decode_datetime!(Map.fetch!(goal, :created_at)),
      updated_at: decode_datetime!(Map.fetch!(goal, :updated_at))
    }
  end

  defp decode_datetime!(%DateTime{} = datetime), do: datetime

  defp decode_datetime!(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      _error -> raise ArgumentError, "invalid goal datetime: #{inspect(value)}"
    end
  end
end

defimpl Vibe.Storage.Persistable, for: Vibe.Goals.Goal do
  def persist(goal) do
    %Vibe.Storage.Representation.Goal{
      session_id: goal.session_id,
      goal_id: goal.goal_id,
      objective: goal.objective,
      status: goal.status,
      token_budget: goal.token_budget,
      tokens_used: goal.tokens_used,
      time_used_seconds: goal.time_used_seconds,
      created_at: goal.created_at,
      updated_at: goal.updated_at
    }
  end
end

defimpl Vibe.Storage.Restorable, for: Vibe.Storage.Representation.Goal do
  def restore(goal) do
    %Vibe.Goals.Goal{
      session_id: goal.session_id,
      goal_id: goal.goal_id,
      objective: goal.objective,
      status: goal.status,
      token_budget: goal.token_budget,
      tokens_used: goal.tokens_used,
      time_used_seconds: goal.time_used_seconds,
      created_at: goal.created_at,
      updated_at: goal.updated_at
    }
  end
end

defimpl Jason.Encoder, for: Vibe.Storage.Representation.Goal do
  def encode(goal, opts) do
    goal
    |> Map.from_struct()
    |> Vibe.Storage.JSON.value()
    |> Jason.Encode.map(opts)
  end
end
