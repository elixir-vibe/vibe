defmodule Vibe.Subagents.Supervisor do
  @moduledoc "DynamicSupervisor for subagent job processes."
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children = [
      Vibe.Subagents.Manager,
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Subagents.JobSupervisor},
      Vibe.Subagents.Scheduler
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
