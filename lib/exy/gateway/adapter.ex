defmodule Exy.Gateway.Adapter do
  @moduledoc """
  Behaviour implemented by outbound messaging gateway adapters.

  Stream consumers and session bridges use this contract instead of calling a
  platform SDK directly. Telegram can edit messages; future backends can return
  `{:error, :unsupported}` from optional callbacks and let the generic gateway
  fall back to plain sends.
  """

  @type send_result :: {:ok, String.t() | nil} | {:error, term()}

  @callback send(chat_id :: String.t(), text :: String.t(), opts :: keyword()) :: send_result()
  @callback edit(
              chat_id :: String.t(),
              message_id :: String.t(),
              text :: String.t(),
              opts :: keyword()
            ) ::
              send_result()
  @callback delete(chat_id :: String.t(), message_id :: String.t(), opts :: keyword()) ::
              :ok | {:error, term()}
  @callback typing(chat_id :: String.t(), opts :: keyword()) :: :ok | {:error, term()}

  @optional_callbacks delete: 3, typing: 2
end
