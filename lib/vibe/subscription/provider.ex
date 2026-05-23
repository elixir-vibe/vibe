defmodule Vibe.Subscription.Provider do
  @moduledoc """
  Behaviour for provider-specific subscription/account usage backends.
  """

  @callback usage(keyword()) :: {:ok, map()} | {:error, term()}
  @callback account(keyword()) :: {:ok, map()} | {:error, term()}
end
