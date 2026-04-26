defmodule Exy.Subagents.Supervisor do
  @moduledoc false

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    children = [
      Exy.Subagents.Manager,
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Subagents.JobSupervisor},
      Exy.Subagents.Scheduler
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
