defmodule Vibe.Auth.WebToken do
  @moduledoc false

  @spec token() :: String.t()
  def token do
    path = token_path()
    ensure_token_file!(path)
    path |> File.read!() |> String.trim()
  end

  @spec authenticated_url(keyword()) :: String.t()
  def authenticated_url(opts \\ []) do
    port = Keyword.get(opts, :port, 4321)
    "http://localhost:#{port}/?token=#{token()}"
  end

  @spec token_path() :: String.t()
  def token_path, do: Path.join(Vibe.Paths.home(), "web-token")

  defp ensure_token_file!(path) do
    File.mkdir_p!(Path.dirname(path))
    if missing?(path), do: write_token_file!(path)
  end

  defp missing?(path), do: not File.exists?(path)

  defp write_token_file!(path) do
    File.write!(path, random_token())
    File.chmod!(path, 0o600)
  end

  defp random_token do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
