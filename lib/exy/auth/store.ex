defmodule Exy.Auth.Store do
  @moduledoc false

  @auth_path Path.expand("~/.exy/auth.json")

  @spec path() :: Path.t()
  def path, do: @auth_path

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def load(provider) do
    with {:ok, text} <- File.read(@auth_path),
         {:ok, json} <- Jason.decode(text),
         credentials when is_map(credentials) <- Map.get(json, provider) do
      {:ok, credentials}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec save(String.t(), map()) :: :ok
  def save(provider, credentials) do
    File.mkdir_p!(Path.dirname(@auth_path))

    auth =
      case File.read(@auth_path) do
        {:ok, text} -> Jason.decode!(text)
        _ -> %{}
      end

    File.write!(@auth_path, Jason.encode!(Map.put(auth, provider, credentials), pretty: true))
  end
end
