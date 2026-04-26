defmodule Exy.Auth.Store do
  @moduledoc false

  @spec path() :: Path.t()
  def path, do: Exy.Paths.auth_file()

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def load(provider) do
    with {:ok, text} <- File.read(path()),
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
    path = path()
    File.mkdir_p!(Path.dirname(path))

    auth =
      case File.read(path) do
        {:ok, text} -> Jason.decode!(text)
        _ -> %{}
      end

    File.write!(path, Jason.encode!(Map.put(auth, provider, credentials), pretty: true))
  end
end
