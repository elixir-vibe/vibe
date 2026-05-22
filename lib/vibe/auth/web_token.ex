defmodule Vibe.Auth.WebToken do
  @moduledoc false

  @spec token() :: String.t()
  def token do
    Vibe.Auth.WebToken.FileStore.read_or_create!(token_path(), &random_token/0)
  end

  @spec authenticated_url(keyword()) :: String.t()
  def authenticated_url(opts \\ []) do
    port = Keyword.get(opts, :port, 4321)
    "http://localhost:#{port}/?token=#{token()}"
  end

  @spec token_path() :: String.t()
  def token_path, do: Path.join(Vibe.Paths.home(), "web-token")

  defp random_token do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
