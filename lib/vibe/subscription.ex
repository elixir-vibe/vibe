defmodule Vibe.Subscription do
  @moduledoc """
  Provider-neutral subscription/account usage registry.
  """

  @builtin %{
    "openai-codex" => Vibe.Subscription.Provider.OpenAICodex,
    "codex" => Vibe.Subscription.Provider.OpenAICodex
  }

  @spec provider(String.t() | atom()) :: module() | nil
  def provider(name) do
    name = to_string(name)
    Map.get(providers(), name)
  end

  @spec providers() :: %{String.t() => module()}
  def providers do
    configured = Application.get_env(:vibe, :subscription_providers, %{})
    Map.merge(@builtin, stringify_provider_keys(configured))
  end

  @spec usage(String.t() | atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def usage(name, opts \\ []), do: dispatch(name, :usage, [opts])

  @spec account(String.t() | atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def account(name, opts \\ []), do: dispatch(name, :account, [opts])

  defp dispatch(name, function, args) do
    case provider(name) do
      nil -> {:error, {:unknown_subscription_provider, name}}
      module -> apply(module, function, args)
    end
  end

  defp stringify_provider_keys(providers) do
    Map.new(providers, fn {key, module} -> {to_string(key), module} end)
  end
end
