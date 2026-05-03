defmodule Exy.Auth.OpenCode do
  @moduledoc """
  OpenCode API-key authentication for opencode and opencode-go providers.

  Stores a single API key used for both `opencode:*` and `opencode_go:*` model
  prefixes against OpenAI-compatible endpoints at opencode.ai.
  """

  @behaviour Exy.Auth.Provider

  alias Exy.Auth.Store

  @env_var "OPENCODE_API_KEY"

  @base_urls %{
    "opencode" => "https://opencode.ai/zen/v1",
    "opencode_go" => "https://opencode.ai/zen/go/v1"
  }

  @impl true
  def id, do: "opencode"

  @impl true
  def model_prefixes, do: ["opencode", "opencode_go"]

  @impl true
  def resolve_model(prefix, model_id) do
    base_url = @base_urls[prefix]

    model =
      case LLMDB.model(:opencode, model_id) do
        {:ok, llmdb_model} ->
          %{llmdb_model | provider: :openai, base_url: base_url}

        {:error, _} ->
          {:ok, inline} = ReqLLM.model(%{provider: :openai, id: model_id, base_url: base_url})
          inline
      end

    {model, []}
  end

  @impl true
  def request_options do
    case api_key() do
      key when is_binary(key) -> [api_key: key]
      nil -> []
    end
  end

  @impl true
  def login(opts \\ []) do
    key = Keyword.get(opts, :api_key) || System.get_env(@env_var) || prompt_key()
    key = String.trim(to_string(key || ""))

    if key == "" do
      {:error, :missing_api_key}
    else
      credentials = %{"api_key" => key}
      Store.save(id(), credentials)
      put_credentials(credentials)
      {:ok, credentials}
    end
  end

  @impl true
  def refresh(credentials), do: {:ok, credentials}

  @impl true
  def load do
    with {:error, _} <- Store.load(id()),
         {:error, _} <- load_env() do
      {:error, :not_found}
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
  def put_credentials(%{"api_key" => key}) when is_binary(key) and key != "" do
    Application.put_env(:exy, :opencode_credentials, %{api_key: key})
    :ok
  end

  def put_credentials(%{api_key: key}) when is_binary(key),
    do: put_credentials(%{"api_key" => key})

  @impl true
  def usage(_opts \\ []), do: {:error, :unsupported}

  @spec api_key() :: String.t() | nil
  def api_key do
    case Application.get_env(:exy, :opencode_credentials) do
      %{api_key: key} when is_binary(key) -> key
      _ -> nil
    end
  end

  defp load_env do
    case System.get_env(@env_var) do
      key when is_binary(key) and key != "" -> {:ok, %{"api_key" => key}}
      _ -> {:error, :not_found}
    end
  end

  defp prompt_key do
    IO.gets("OpenCode API key: ")
  end
end
