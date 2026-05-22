defmodule Vibe.Auth.Store do
  @moduledoc "JSON-backed credential storage under `~/.vibe/auth.json`."
  @spec path() :: Path.t()
  def path, do: Vibe.Paths.auth_file()

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def load(provider) do
    with {:ok, text} <- File.read(path()),
         {:ok, json} <- Jason.decode(text),
         credentials when is_map(credentials) <- Map.get(json, provider) do
      {:ok, credentials}
    else
      nil -> {:error, :not_found}
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec save(String.t(), map()) :: :ok
  def save(provider, credentials) do
    path = path()
    File.mkdir_p!(Path.dirname(path))

    path
    |> auth_data()
    |> Map.put(provider, credentials)
    |> Jason.encode!(pretty: true)
    |> then(&File.write!(path, &1))
  end

  defp auth_data(path) do
    case File.read(path) do
      {:ok, text} -> Jason.decode!(text)
      _ -> %{}
    end
  end
end
