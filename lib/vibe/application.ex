defmodule Vibe.Application do
  @moduledoc "OTP application supervisor."
  use Application

  @slow_jido_signal_threshold_ms 1_000
  @slow_jido_directive_threshold_ms 1_000

  @impl true
  def start(_type, _args) do
    configure_dependency_logging()
    Vibe.Storage.configure_repo()

    children = [
      Vibe.Repo,
      {Registry, keys: :unique, name: Vibe.Registry},
      {Phoenix.PubSub, name: Vibe.PubSub},
      Vibe.Telemetry,
      {Jido, name: Jido, otp_app: :vibe},
      Vibe.Jido,
      Vibe.Subagents.Supervisor,
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Agent.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Code.LSP.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Command.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Terminal.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Eval.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Plugin.Supervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.Gateway.BridgeSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Vibe.SessionSupervisor},
      {Task.Supervisor, name: Vibe.TaskSupervisor},
      {Task.Supervisor, name: Vibe.UI.PluginTaskSupervisor},
      Vibe.UI.Bus,
      Vibe.SystemAlarms,
      Vibe.Session.Processes,
      Vibe.Agent.Memory,
      Vibe.Agent.Streaming,
      Vibe.Model.Transport.WebSocketPool,
      Vibe.Plugin.Manager,
      Vibe.Memory.Manager
    ]

    children = children ++ gateway_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: Vibe.Supervisor)
  end

  defp gateway_children do
    case Application.get_env(:vibe, :gateways, []) do
      [] -> []
      gateways -> [{Vibe.Gateway.Supervisor, gateways: gateways, name: Vibe.Gateway.Supervisor}]
    end
  end

  @doc """
  Applies Vibe’s quiet default log levels for chatty dependencies.
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
