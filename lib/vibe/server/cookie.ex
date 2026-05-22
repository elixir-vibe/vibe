defmodule Vibe.Server.Cookie do
  @moduledoc "Erlang distribution cookie management for the background server."
  @spec path() :: Path.t()
  def path, do: Vibe.Paths.server_cookie()

  @spec get() :: atom()
  def get do
    path = path()
    File.mkdir_p!(Path.dirname(path))
    if missing?(path), do: write_cookie!(path)

    path
    |> File.read!()
    |> String.trim()
    |> :erlang.binary_to_atom()
  end

  defp missing?(path), do: not File.exists?(path)

  defp write_cookie!(path) do
    File.write!(path, random_cookie(), [:write])
    File.chmod!(path, 0o600)
  end

  defp random_cookie do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
