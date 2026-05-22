defmodule Vibe.Model.Selection do
  @moduledoc """
  Model selection and provider discovery.

  Model strings use `provider:model_id` format (e.g. `"anthropic:claude-sonnet-4"`).
  Any provider supported by ReqLLM works — Vibe passes the string through and
  ReqLLM handles resolution, wire protocol, and env-var-based authentication.

  Providers that need OAuth or interactive login (e.g. OpenAI Codex) have
  dedicated `Vibe.Auth.Provider` wrappers. All others use standard env vars
  like `ANTHROPIC_API_KEY`, `ZAI_API_KEY`, `DEEPSEEK_API_KEY`, etc.
  """

  @doc "Returns the configured default model identifier."
  @spec default() :: String.t()
  def default, do: Vibe.Model.Default.model()

  @spec resolve(keyword()) :: String.t()
  def resolve(opts \\ []) do
    Vibe.Model.Selection.Source.resolve(opts, &default/0)
  end

  @doc """
  Returns ReqLLM provider atoms that have API credentials available.

  Checks env vars, application config, and Vibe's persisted auth store.
  Useful for showing which providers are ready to use.
  """
  @spec available_providers() :: [atom()]
  def available_providers do
    ReqLLM.Provider.Generated.ValidProviders.list()
    |> Enum.filter(&provider_has_credentials?/1)
    |> Enum.sort()
  end

  defp provider_has_credentials?(provider) do
    match?({:ok, _, _}, ReqLLM.Keys.get(provider, []))
  rescue
    _error -> false
  end
end
