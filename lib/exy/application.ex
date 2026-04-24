defmodule Exy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Exy.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Subagents.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.LSP.Supervisor},
      Exy.Trajectory.Store,
      Exy.Plugin.Manager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Exy.Supervisor)
  end
end
