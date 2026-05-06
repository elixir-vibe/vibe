defmodule Exy.Gateway.Telegram do
  @moduledoc """
  Convenience API for starting the Telegram gateway backend.

  The generic gateway runtime and supervisor remain backend-neutral; this module
  provides a small Telegram-specific entrypoint for CLI and future server config
  surfaces.
  """

  alias Exy.Gateway.Telegram.Backend

  @doc "Starts a foreground Telegram polling gateway under Exy's top-level supervisor."
  @spec start_polling(keyword()) :: Supervisor.on_start_child()
  def start_polling(opts \\ []) do
    opts = Keyword.put(opts, :method, :polling)

    Supervisor.start_child(Exy.Supervisor, %{
      id: Exy.Gateway.Telegram.Supervisor,
      start:
        {Exy.Gateway.Supervisor, :start_link,
         [
           gateways: [
             [
               id: :telegram,
               backend: Backend,
               backend_opts: opts
             ]
           ],
           name: Exy.Gateway.Telegram.Supervisor
         ]}
    })
  end

  @doc "Stops the foreground Telegram polling gateway when it is running."
  @spec stop_polling() :: :ok | {:error, term()}
  def stop_polling do
    with :ok <- Supervisor.terminate_child(Exy.Supervisor, Exy.Gateway.Telegram.Supervisor) do
      Supervisor.delete_child(Exy.Supervisor, Exy.Gateway.Telegram.Supervisor)
    end
  end

  @doc "Returns Telegram Bot API getMe for the configured token."
  @spec get_me(keyword()) :: {:ok, term()} | {:error, term()}
  def get_me(opts \\ []) do
    with {:ok, config} <- Exy.Gateway.Telegram.Config.load(opts) do
      ExGram.get_me(token: config.token)
    end
  end

  @doc "Returns Telegram Bot API webhook info for the configured token."
  @spec webhook_info(keyword()) :: {:ok, term()} | {:error, term()}
  def webhook_info(opts \\ []) do
    with {:ok, config} <- Exy.Gateway.Telegram.Config.load(opts) do
      ExGram.get_webhook_info(token: config.token)
    end
  end

  @doc "Runs one short getUpdates request for diagnostics."
  @spec get_updates_once(keyword()) :: {:ok, term()} | {:error, term()}
  def get_updates_once(opts \\ []) do
    with {:ok, config} <- Exy.Gateway.Telegram.Config.load(opts) do
      ExGram.get_updates(
        token: config.token,
        limit: 5,
        timeout: 1,
        receive_timeout: config.poll_receive_timeout_ms
      )
    end
  end
end
