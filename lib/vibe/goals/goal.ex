defmodule Vibe.Goals.Goal do
  @moduledoc "Persisted long-running goal for a Vibe session."

  @statuses [:active, :paused, :blocked, :usage_limited, :budget_limited, :complete]

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

  @type status :: :active | :paused | :blocked | :usage_limited | :budget_limited | :complete

  @type t :: %__MODULE__{
          session_id: String.t(),
          goal_id: String.t(),
          objective: String.t(),
          status: status(),
          token_budget: pos_integer() | nil,
          tokens_used: non_neg_integer(),
          time_used_seconds: non_neg_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @spec statuses() :: [status()]
  def statuses, do: @statuses

  @spec status(atom() | String.t()) :: {:ok, status()} | {:error, term()}
  def status(status) when status in @statuses, do: {:ok, status}

  def status(status) when is_binary(status) do
    status
    |> String.downcase()
    |> String.replace("-", "_")
    |> then(fn status -> Enum.find(@statuses, &(Atom.to_string(&1) == status)) end)
    |> case do
      nil -> {:error, {:unknown_goal_status, status}}
      status -> {:ok, status}
    end
  end

  def status(status), do: {:error, {:unknown_goal_status, status}}

  @spec active?(t() | nil) :: boolean()
  def active?(%__MODULE__{status: :active}), do: true
  def active?(_goal), do: false
end

defimpl Jason.Encoder, for: Vibe.Goals.Goal do
  def encode(goal, opts) do
    Jason.Encode.map(
      %{
        session_id: goal.session_id,
        goal_id: goal.goal_id,
        objective: goal.objective,
        status: goal.status,
        token_budget: goal.token_budget,
        tokens_used: goal.tokens_used,
        time_used_seconds: goal.time_used_seconds,
        created_at: goal.created_at,
        updated_at: goal.updated_at
      },
      opts
    )
  end
end
