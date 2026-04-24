defmodule Exy.Budget do
  @moduledoc """
  Small immutable budget struct for recursive/subagent work.
  """

  defstruct max_depth: 2,
            depth: 0,
            max_children_per_node: 3,
            max_total_agents: 16,
            started_at: nil,
            max_wall_time_ms: 300_000

  @type t :: %__MODULE__{}

  @spec new(keyword() | map()) :: t()
  def new(opts \\ []) do
    opts = Map.new(opts)

    %__MODULE__{
      max_depth: Map.get(opts, :max_depth, 2),
      depth: Map.get(opts, :depth, 0),
      max_children_per_node: Map.get(opts, :max_children_per_node, 3),
      max_total_agents: Map.get(opts, :max_total_agents, 16),
      max_wall_time_ms: Map.get(opts, :max_wall_time_ms, 300_000),
      started_at: Map.get(opts, :started_at, System.monotonic_time(:millisecond))
    }
  end

  @spec allowed?(t()) :: boolean()
  def allowed?(%__MODULE__{} = budget) do
    budget.depth <= budget.max_depth and elapsed(budget) <= budget.max_wall_time_ms
  end

  @spec child(t()) :: t()
  def child(%__MODULE__{} = budget), do: %{budget | depth: budget.depth + 1}

  @spec elapsed(t()) :: non_neg_integer()
  def elapsed(%__MODULE__{} = budget), do: System.monotonic_time(:millisecond) - budget.started_at
end
