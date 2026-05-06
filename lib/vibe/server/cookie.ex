defmodule Vibe.Server.Cookie do
  @moduledoc "Erlang distribution cookie management for the background server."
  @spec path() :: Path.t()
  def path, do: Vibe.Paths.server_cookie()

  @spec get() :: atom()
  def get do
    path = path()
    File.mkdir_p!(Path.dirname(path))

    unless File.exists?(path) do
      cookie = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
      File.write!(path, cookie, [:write])
      File.chmod!(path, 0o600)
    end

    path
    |> File.read!()
    |> String.trim()
    |> String.to_atom()
  end
end
