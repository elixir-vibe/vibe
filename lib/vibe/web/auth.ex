defmodule Vibe.Web.Auth do
  @moduledoc """
  Token-based authentication for the web console.

  Generates a random token on first startup, persists it to
  `~/.vibe/web-token` (mode 0600). The token is checked on every
  request — passed as `?token=xxx` query param on first visit,
  then stored in a session cookie.
  """

  import Plug.Conn

  @token_session_key "vibe_web_auth"

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

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    cond do
      authenticated_session?(conn) ->
        conn

      valid_token_param?(conn) ->
        conn
        |> fetch_session()
        |> put_session(@token_session_key, true)
        |> redirect_without_token()

      true ->
        conn
        |> send_resp(401, "Unauthorized — open Vibe web via /web or pass ?token=")
        |> halt()
    end
  end

  defp authenticated_session?(conn) do
    conn = fetch_session(conn)
    get_session(conn, @token_session_key) == true
  end

  defp valid_token_param?(conn) do
    conn = fetch_query_params(conn)
    Map.get(conn.query_params, "token") == token()
  end

  defp redirect_without_token(conn) do
    path = conn.request_path

    conn
    |> Phoenix.Controller.redirect(to: path)
    |> halt()
  end
end
