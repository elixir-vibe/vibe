defmodule Exy.Auth do
  @moduledoc """
  Auth provider registry and dispatch.
  """

  @builtin %{
    "openai-codex" => Exy.Auth.Codex,
    "codex" => Exy.Auth.Codex,
    "openrouter" => Exy.Auth.OpenRouter,
    "open-router" => Exy.Auth.OpenRouter
  }

  @spec provider(String.t() | atom()) :: module() | nil
  def provider(name) do
    name = to_string(name)
    Map.get(providers(), name)
  end

  @spec providers() :: %{String.t() => module()}
  def providers do
    configured = Application.get_env(:exy, :auth_providers, %{})
    Map.merge(@builtin, stringify_provider_keys(configured))
  end

  @spec login(String.t() | atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def login(name, opts \\ []), do: dispatch(name, :login, [opts])

  @spec ensure_fresh(String.t() | atom()) :: {:ok, map()} | {:error, term()}
  def ensure_fresh(name \\ "openai-codex"), do: dispatch(name, :ensure_fresh, [])

  @spec usage(String.t() | atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def usage(name \\ "openai-codex", opts \\ []), do: dispatch(name, :usage, [opts])

  defp dispatch(name, function, args) do
    case provider(name) do
      nil -> {:error, {:unknown_auth_provider, name}}
      module -> apply(module, function, args)
    end
  end

  defp stringify_provider_keys(providers) do
    Map.new(providers, fn {key, module} -> {to_string(key), module} end)
  end
end
