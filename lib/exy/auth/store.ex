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

    File.write!(
      path,
      Jason.encode!(Map.put(auth, provider, json_safe(credentials)), pretty: true)
    )
  end

  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {json_key(key), json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(value), do: value

  defp json_key(key) when is_atom(key), do: Atom.to_string(key)
  defp json_key(key) when is_binary(key), do: key
  defp json_key(key), do: inspect(key)
end
