defmodule Exy.Auth.Provider do
  @moduledoc """
  Behaviour for authentication providers.

  Providers own protocol-specific login/refresh and token-to-LLM wiring. Shared
  storage/callback plumbing lives outside providers so additional sign-in options
  can be added without duplicating persistence code.
  """

  @type credentials :: map()

  @callback id() :: String.t()
  @callback login(keyword()) :: {:ok, credentials()} | {:error, term()}
  @callback refresh(credentials()) :: {:ok, credentials()} | {:error, term()}
  @callback load() :: {:ok, credentials()} | {:error, term()}
  @callback ensure_fresh() :: {:ok, credentials()} | {:error, term()}
  @callback put_credentials(credentials()) :: :ok | {:error, term()}
  @callback usage(keyword()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks usage: 1
end
