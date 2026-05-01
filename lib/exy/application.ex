defmodule Exy.Application do
  @moduledoc "Internal implementation module."
  use Application

  @slow_jido_signal_threshold_ms 1_000
  @slow_jido_directive_threshold_ms 1_000

  @impl true
  def start(_type, _args) do
    configure_dependency_logging()
    Exy.Storage.configure_repo()

    children = [
      Exy.Repo,
      {Registry, keys: :unique, name: Exy.Registry},
      {Phoenix.PubSub, name: Exy.PubSub},
      Exy.Telemetry,
      {Jido, name: Jido, otp_app: :exy},
      Exy.Jido,
      Exy.Subagents.Supervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Agent.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Code.LSP.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Command.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Terminal.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Eval.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.Plugin.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Exy.SessionSupervisor},
      {Task.Supervisor, name: Exy.TaskSupervisor},
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

  @doc """
  Applies Exy’s quiet default log levels for chatty dependencies.
  """
  def configure_dependency_logging do
    Logger.put_application_level(:jido, :warning)
    Logger.put_application_level(:jido_action, :warning)
    Logger.put_application_level(:jido_ai, :warning)
    Logger.put_application_level(:jido_signal, :warning)
    Logger.put_application_level(:req_llm, :warning)

    Application.put_env(:jido, :telemetry,
      log_level: :error,
      log_args: :none,
      slow_signal_threshold_ms: @slow_jido_signal_threshold_ms,
      slow_directive_threshold_ms: @slow_jido_directive_threshold_ms
    )

    Application.put_env(:jido, :observability, log_level: :warning)
  end
end
