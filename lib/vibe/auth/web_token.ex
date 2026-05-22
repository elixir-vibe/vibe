defmodule Vibe.Auth.WebToken do
  @moduledoc false

  @spec token() :: String.t()
  def token do
    path = token_path()
    File.mkdir_p!(Path.dirname(path))

    unless File.exists?(path) do
      secret = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
      File.write!(path, secret)
      File.chmod!(path, 0o600)
    end

    path |> File.read!() |> String.trim()
  end

  @spec authenticated_url(keyword()) :: String.t()
  def authenticated_url(opts \\ []) do
    port = Keyword.get(opts, :port, 4321)
    "http://localhost:#{port}/?token=#{token()}"
  end

  @spec token_path() :: String.t()
  def token_path, do: Path.join(Vibe.Paths.home(), "web-token")
end
