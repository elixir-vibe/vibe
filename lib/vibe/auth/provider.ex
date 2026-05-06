defmodule Vibe.Auth.Provider do
  @moduledoc """
  Behaviour for authentication providers.

  Providers own protocol-specific login/refresh and token-to-LLM wiring. Shared
  storage/callback plumbing lives outside providers so additional sign-in options
  can be added without duplicating persistence code.
  """

  @type credentials :: map()
  @type request_option :: {atom(), term()}

  @callback id() :: String.t()
  @callback model_prefixes() :: [String.t()]
  @callback resolve_model(prefix :: String.t(), model_id :: String.t()) ::
              {reqllm_model :: term(), [request_option()]}
  @callback request_options() :: [request_option()]
  @callback login(keyword()) :: {:ok, credentials()} | {:error, term()}
  @callback refresh(credentials()) :: {:ok, credentials()} | {:error, term()}
  @callback load() :: {:ok, credentials()} | {:error, term()}
  @callback ensure_fresh() :: {:ok, credentials()} | {:error, term()}
  @callback put_credentials(credentials()) :: :ok | {:error, term()}
  @callback usage(keyword()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks usage: 1

  @spec for_model(String.t(), %{String.t() => module()}) ::
          {module(), String.t(), String.t()} | nil
  def for_model(model, providers \\ Vibe.Auth.providers()) do
    providers
    |> Map.values()
    |> Enum.uniq()
    |> Enum.find_value(fn module ->
      Enum.find_value(module.model_prefixes(), fn prefix ->
        if String.starts_with?(model, prefix <> ":") do
          model_id = String.trim_leading(model, prefix <> ":")
          {module, prefix, model_id}
        end
      end)
    end)
  end
end
