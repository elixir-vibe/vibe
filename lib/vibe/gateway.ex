defmodule Vibe.Gateway do
  @moduledoc """
  Introspection helpers for external gateway runtimes.

  Gateway workers are still started by `Vibe.Gateway.Supervisor`; this module
  provides renderer-neutral status data for CLI/Web dashboards without exposing
  platform implementation details.
  """

  @doc "Returns configured and known gateway runtime statuses."
  @spec statuses() :: [map()]
  def statuses do
    configured = Application.get_env(:vibe, :gateways, [])

    configured
    |> Enum.map(&status_from_config/1)
    |> ensure_known_telegram_status()
  end

  @doc "Returns recent Vibe sessions created by gateways."
  @spec sessions(keyword()) :: [map()]
  def sessions(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Vibe.Session.list()
    |> Enum.filter(&String.starts_with?(&1.id, "gateway:"))
    |> Enum.take(limit)
    |> Enum.map(&put_source_parts/1)
  end

  defp ensure_known_telegram_status(statuses) do
    if Enum.any?(statuses, &(&1.id == :telegram)) do
      statuses
    else
      [runtime_status(:telegram, Vibe.Gateway.Telegram.Backend, nil) | statuses]
    end
    |> Enum.reject(&(&1.status == :not_configured and &1.id != :telegram))
  end

  defp status_from_config(opts) do
    id = Keyword.fetch!(opts, :id)
    backend = Keyword.fetch!(opts, :backend)
    config = Keyword.get(opts, :config)
    runtime_status(id, backend, config)
  end

  defp runtime_status(id, backend, config) do
    runtime = {:via, Registry, {Vibe.Registry, {:gateway_runtime, id}}}

    case Registry.lookup(Vibe.Registry, {:gateway_runtime, id}) do
      [{pid, _value}] ->
        %{
          id: id,
          backend: backend,
          pid: inspect(pid),
          status: :running,
          stats: Vibe.Gateway.Runtime.stats(runtime),
          config: config_summary(config)
        }

      [] ->
        %{
          id: id,
          backend: backend,
          pid: nil,
          status: if(config, do: :stopped, else: :not_configured),
          stats: %{accepted: 0, ignored: 0, rejected: 0, failed: 0},
          config: config_summary(config)
        }
    end
  end

  defmodule SessionSourceParts do
    @moduledoc false
    defstruct [:platform, :chat_type, :chat_id, :thread_id, :user_id]
  end

  defp config_summary(nil), do: %{}

  defp config_summary(config) do
    config
    |> Map.from_struct()
    |> Map.drop([:token, :webhook_secret])
  end

  defp put_source_parts(session) do
    Map.put(session, :gateway_source, parse_session_id(session.id))
  end

  defp parse_session_id("gateway:" <> rest) do
    case String.split(rest, ":") do
      [platform, chat_type, chat_id] ->
        %SessionSourceParts{platform: platform, chat_type: chat_type, chat_id: chat_id}

      [platform, chat_type, chat_id, thread_id] ->
        %SessionSourceParts{
          platform: platform,
          chat_type: chat_type,
          chat_id: chat_id,
          thread_id: thread_id
        }

      [platform, chat_type, chat_id, thread_id, user_id] ->
        %SessionSourceParts{
          platform: platform,
          chat_type: chat_type,
          chat_id: chat_id,
          thread_id: thread_id,
          user_id: user_id
        }

      _other ->
        %{}
    end
  end
end
