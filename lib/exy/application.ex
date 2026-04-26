defmodule Exy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    configure_dependency_logging()

    children = [
      {Registry, keys: :unique, name: Exy.Registry},
      Exy.Telemetry,
      {Jido, name: Jido, otp_app: :exy},
      Exy.Jido,
      Exy.Subagents.Supervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Agent.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Code.LSP.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Terminal.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Eval.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Plugin.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.SessionSupervisor},
      {Task.Supervisor, name: Exy.UI.PluginTaskSupervisor},
      Exy.UI.Bus,
      Exy.Session.Processes,
      Exy.Agent.Memory,
      Exy.Agent.Streaming,
      Exy.Plugin.Manager,
      Exy.Memory.Manager
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Exy.Supervisor)
  end

  @doc false
  def configure_dependency_logging do
    Logger.put_application_level(:jido, :warning)
    Logger.put_application_level(:jido_action, :warning)
    Logger.put_application_level(:jido_ai, :warning)
    Logger.put_application_level(:jido_signal, :warning)
    Logger.put_application_level(:req_llm, :warning)

    Application.put_env(:jido, :telemetry,
      log_level: :error,
      log_args: :none,
      slow_signal_threshold_ms: 1_000,
      slow_directive_threshold_ms: 1_000
    )

    Application.put_env(:jido, :observability, log_level: :warning)
  end
end
