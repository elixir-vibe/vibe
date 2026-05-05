defmodule Exy.Gateway.Backend do
  @moduledoc """
  Behaviour for external chat gateway backends.

  Backends own platform details such as Telegram update payloads, Bot API
  clients, mentions, and auth rules. `Exy.Gateway.Runtime` owns the generic
  Exy flow: normalize, gate, derive a session key, and dispatch to a semantic
  session.
  """

  alias Exy.Gateway.Message

  @type config :: struct() | map()
  @type normalized :: %{message: Message.t(), trigger: map()}

  @callback load_config(keyword()) :: {:ok, config()} | {:error, term()}
  @callback normalize(term(), config()) :: {:ok, normalized()} | :ignore | {:error, term()}
  @callback authorized?(Message.t(), trigger :: map(), config()) :: boolean()
  @callback outbound_adapter(config()) :: module()
  @callback child_specs(config(), runtime :: pid()) :: [Supervisor.child_spec()]

  @optional_callbacks child_specs: 2
end
