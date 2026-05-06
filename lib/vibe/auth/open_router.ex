defmodule Vibe.Auth.OpenRouter do
  @moduledoc """
  OpenRouter API-key authentication.
  """

  @behaviour Vibe.Auth.Provider

  alias Vibe.Auth.Store

  @impl true
  def id, do: "openrouter"

  @impl true
  def model_prefixes, do: ["openrouter"]

  @impl true
  def resolve_model(_prefix, model_id), do: {"openrouter:#{model_id}", []}

  @impl true
  def request_options do
    case Application.get_env(:vibe, :openrouter_credentials) do
      %{api_key: key} when is_binary(key) -> [api_key: key]
      _ -> []
    end
  end

  @impl true
  def login(opts \\ []) do
    key = Keyword.get(opts, :api_key) || System.get_env("OPENROUTER_API_KEY") || prompt_key()
    credentials = %{"api_key" => String.trim(to_string(key || ""))}

    if credentials["api_key"] == "" do
      {:error, :missing_api_key}
    else
      Store.save(id(), credentials)
      put_credentials(credentials)
      {:ok, credentials}
    end
  end

  @impl true
  def refresh(credentials), do: {:ok, credentials}

  @impl true
  def load do
    case Store.load(id()) do
      {:ok, credentials} -> {:ok, credentials}
      {:error, _reason} = error -> load_env(error)
    end
  end

  @impl true
  def ensure_fresh do
    with {:ok, credentials} <- load() do
      put_credentials(credentials)
      {:ok, credentials}
    end
  end

  @impl true
  def put_credentials(%{"api_key" => key}) when is_binary(key) do
    ReqLLM.put_key(:openrouter_api_key, key)
    Application.put_env(:vibe, :openrouter_credentials, %{api_key: key})
    :ok
  end

  def put_credentials(%{api_key: key}) when is_binary(key),
    do: put_credentials(%{"api_key" => key})

  @impl true
  def usage(_opts \\ []), do: {:error, :unsupported}

  defp load_env(fallback) do
    case System.get_env("OPENROUTER_API_KEY") do
      key when is_binary(key) and key != "" -> {:ok, %{"api_key" => key}}
      _key -> fallback
    end
  end

  defp prompt_key do
    IO.gets("OpenRouter API key: ")
  end
end
