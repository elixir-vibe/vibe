defmodule Exy.Budget do
  @moduledoc """
  Small immutable budget struct for recursive/subagent work.
  """

  @default_max_depth 2
  @default_max_children_per_node 3
  @default_max_total_agents 16
  @default_max_wall_time_ms 300_000

  defstruct max_depth: @default_max_depth,
            depth: 0,
            max_children_per_node: @default_max_children_per_node,
            max_total_agents: @default_max_total_agents,
            started_at: nil,
            max_wall_time_ms: @default_max_wall_time_ms

  @type t :: %__MODULE__{}

  @spec new(keyword() | map()) :: t()
  def new(opts \\ []) do
    opts = Map.new(opts)

    %__MODULE__{
      max_depth: Map.get(opts, :max_depth, @default_max_depth),
      depth: Map.get(opts, :depth, 0),
      max_children_per_node:
        Map.get(opts, :max_children_per_node, @default_max_children_per_node),
      max_total_agents: Map.get(opts, :max_total_agents, @default_max_total_agents),
      max_wall_time_ms: Map.get(opts, :max_wall_time_ms, @default_max_wall_time_ms),
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
