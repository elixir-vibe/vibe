defmodule Exy.CLI.Commands.Gateway do
  @moduledoc """
  CLI command for running external gateway backends.

  Currently supports a foreground Telegram polling gateway for local dogfooding:

      exy gateway telegram --foreground
  """

  @behaviour Exy.CLI.Command

  alias Exy.CLI.Output
  alias Exy.Gateway.Telegram

  @impl true
  def names, do: ["gateway"]

  @impl true
  def run(["gateway", "telegram" | _args], opts) do
    telegram_opts = telegram_opts(opts)

    with {:ok, _pid} <- Telegram.start_polling(telegram_opts) do
      Output.print(%{summary: "Telegram gateway polling started. Press Ctrl+C to stop."}, opts)
      wait_forever()
    end
  end

  def run(["gateway" | _args], opts) do
    Output.print(%{summary: gateway_help()}, opts)
  end

  defp telegram_opts(opts) do
    [
      token: opts[:token],
      bot_id: opts[:bot_id],
      bot_username: opts[:bot_username],
      allow_all?: opts[:allow_all],
      allowed_users: opts[:allowed_users],
      group_allowed_users: opts[:group_allowed_users],
      group_allowed_chats: opts[:group_allowed_chats],
      require_mention?: opts[:require_mention],
      free_response_chats: opts[:free_response_chats],
      stream_mode: opts[:stream_mode]
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp wait_forever do
    receive do
      :stop -> :ok
    end
  end

  defp gateway_help do
    """
    Gateway commands:

      exy gateway telegram --foreground

    Telegram reads TELEGRAM_BOT_TOKEN and related TELEGRAM_* env vars by default.
    Useful options: --token, --bot-id, --bot-username, --allow-all,
    --allowed-users, --group-allowed-chats, --require-mention.
    """
  end
end
