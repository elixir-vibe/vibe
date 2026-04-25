defmodule Exy.Auth.Codex do
  @moduledoc """
  ChatGPT/Codex OAuth login compatible with pi's OpenAI Codex flow.
  """

  @behaviour Exy.Auth.Provider

  @client_id "app_EMoamEEZ73f0CkXaXp7hrann"
  @authorize_url "https://auth.openai.com/oauth/authorize"
  @token_url "https://auth.openai.com/oauth/token"
  @redirect_uri "http://localhost:1455/auth/callback"
  @scope "openid profile email offline_access"
  @claim_path "https://api.openai.com/auth"
  @auth_path Path.expand("~/.exy/auth.json")

  @impl Exy.Auth.Provider
  def id, do: "openai-codex"

  @impl Exy.Auth.Provider
  @spec login(keyword()) :: {:ok, map()} | {:error, term()}
  def login(opts \\ []) do
    verifier = random_urlsafe(64)
    challenge = pkce_challenge(verifier)
    state = random_urlsafe(24)
    url = authorize_url(challenge, state, Keyword.get(opts, :originator, "exy"))

    with {:ok, server} <- start_callback_server(state) do
      maybe_open_browser(url, opts)
      IO.puts("Open this URL to sign in with ChatGPT/Codex:\n\n#{url}\n")
      IO.puts("Waiting on #{@redirect_uri} ...")

      code = wait_for_code(server, Keyword.get(opts, :timeout, 180_000)) || prompt_code(state)
      stop_server(server)

      with {:ok, credentials} <- exchange_code(code, verifier),
           {:ok, credentials} <- attach_account_id(credentials) do
        save(id(), credentials)
        put_credentials(credentials)
        {:ok, credentials}
      end
    end
  end

  @impl Exy.Auth.Provider
  @spec refresh(map()) :: {:ok, map()} | {:error, term()}
  def refresh(%{refresh: refresh}) do
    body =
      URI.encode_query(%{
        grant_type: "refresh_token",
        refresh_token: refresh,
        client_id: @client_id
      })

    body
    |> post_token()
    |> case do
      {:ok, credentials} -> attach_account_id(credentials)
      other -> other
    end
  end

  def refresh(%{"refresh" => refresh}), do: refresh(%{refresh: refresh})

  @impl Exy.Auth.Provider
  @spec load() :: {:ok, map()} | {:error, :not_found | term()}
  def load, do: load(id())

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def load(provider) do
    with {:ok, text} <- File.read(@auth_path),
         {:ok, json} <- Jason.decode(text),
         credentials when is_map(credentials) <- Map.get(json, provider) do
      {:ok, atomize_keys(credentials)}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Exy.Auth.Provider
  @spec usage(keyword()) :: {:ok, map()} | {:error, term()}
  def usage(opts \\ []), do: Exy.Codex.Usage.limits(opts)

  @spec usage_limits(keyword()) :: {:ok, map()} | {:error, term()}
  def usage_limits(opts \\ []), do: usage(opts)

  @impl Exy.Auth.Provider
  @spec ensure_fresh() :: {:ok, map()} | {:error, term()}
  def ensure_fresh do
    with {:ok, credentials} <- load() do
      if Map.get(credentials, :expires, 0) < System.system_time(:millisecond) + 60_000 do
        with {:ok, refreshed} <- refresh(credentials) do
          save(id(), refreshed)
          put_credentials(refreshed)
          {:ok, refreshed}
        end
      else
        put_credentials(credentials)
        {:ok, credentials}
      end
    end
  end

  @impl Exy.Auth.Provider
  @spec put_credentials(map()) :: :ok
  def put_credentials(credentials), do: Exy.LLM.put_codex_credentials(credentials)

  defp exchange_code(code, verifier) do
    %{
      grant_type: "authorization_code",
      client_id: @client_id,
      code: code,
      code_verifier: verifier,
      redirect_uri: @redirect_uri
    }
    |> URI.encode_query()
    |> post_token()
  end

  defp post_token(body) do
    case Req.post(@token_url,
           headers: [{"content-type", "application/x-www-form-urlencoded"}],
           body: body
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> token_result(body)
      {:ok, response} -> {:error, {:http_error, response.status, response.body}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp token_result(body) when is_binary(body), do: body |> Jason.decode!() |> token_result()

  defp token_result(%{
         "access_token" => access,
         "refresh_token" => refresh,
         "expires_in" => expires_in
       }) do
    {:ok,
     %{
       access: access,
       refresh: refresh,
       expires: System.system_time(:millisecond) + expires_in * 1_000
     }}
  end

  defp token_result(body), do: {:error, {:invalid_token_response, body}}

  defp attach_account_id(%{access: access} = credentials) do
    case account_id(access) do
      nil -> {:error, :missing_account_id}
      account_id -> {:ok, Map.put(credentials, :accountId, account_id)}
    end
  end

  defp authorize_url(challenge, state, originator) do
    query =
      URI.encode_query(%{
        response_type: "code",
        client_id: @client_id,
        redirect_uri: @redirect_uri,
        scope: @scope,
        code_challenge: challenge,
        code_challenge_method: "S256",
        state: state,
        id_token_add_organizations: "true",
        codex_cli_simplified_flow: "true",
        originator: originator
      })

    @authorize_url <> "?" <> query
  end

  defp start_callback_server(state) do
    parent = self()

    pid =
      spawn_link(fn ->
        {:ok, listen} =
          :gen_tcp.listen(1455, [
            :binary,
            active: false,
            packet: :raw,
            reuseaddr: true,
            ip: {127, 0, 0, 1}
          ])

        send(parent, {:codex_server_ready, self()})
        accept_once(listen, parent, state)
      end)

    receive do
      {:codex_server_ready, ^pid} -> {:ok, pid}
    after
      2_000 -> {:error, :callback_server_timeout}
    end
  rescue
    exception -> {:error, exception}
  end

  defp accept_once(listen, parent, state) do
    case :gen_tcp.accept(listen, 180_000) do
      {:ok, socket} ->
        {:ok, request} = :gen_tcp.recv(socket, 0, 5_000)
        {status, body, code} = parse_callback(request, state)

        response =
          "HTTP/1.1 #{status}\r\ncontent-type: text/html; charset=utf-8\r\ncontent-length: #{byte_size(body)}\r\n\r\n#{body}"

        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        :gen_tcp.close(listen)
        if code, do: send(parent, {:codex_code, code})

      _ ->
        :gen_tcp.close(listen)
    end
  end

  defp parse_callback(request, state) do
    [request_line | _] = String.split(request, "\r\n", parts: 2)

    with ["GET", target | _] <- String.split(request_line, " "),
         %URI{path: "/auth/callback", query: query} <- URI.parse(target),
         params <- URI.decode_query(query || ""),
         true <- params["state"] == state,
         code when is_binary(code) <- params["code"] do
      {"200 OK",
       "<html><body>OpenAI authentication completed. You can close this window.</body></html>",
       code}
    else
      _ -> {"400 Bad Request", "<html><body>OpenAI authentication failed.</body></html>", nil}
    end
  end

  defp wait_for_code(server, timeout) do
    ref = Process.monitor(server)

    receive do
      {:codex_code, code} ->
        Process.demonitor(ref, [:flush])
        code

      {:DOWN, ^ref, :process, ^server, _reason} ->
        nil
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        nil
    end
  end

  defp stop_server(pid) when is_pid(pid), do: Process.exit(pid, :normal)

  defp prompt_code(state) do
    input = IO.gets("Paste authorization code or redirect URL: ") |> to_string() |> String.trim()
    parse_authorization_input(input, state)
  end

  defp parse_authorization_input(input, state) do
    cond do
      String.contains?(input, "://") ->
        uri = URI.parse(input)
        params = URI.decode_query(uri.query || "")
        if params["state"] in [nil, state], do: params["code"]

      String.contains?(input, "code=") ->
        params = URI.decode_query(input)
        if params["state"] in [nil, state], do: params["code"]

      true ->
        input
    end
  end

  defp maybe_open_browser(url, opts) do
    if Keyword.get(opts, :open_browser, true) do
      cond do
        System.find_executable("open") -> System.cmd("open", [url])
        System.find_executable("xdg-open") -> System.cmd("xdg-open", [url])
        true -> :noop
      end
    end
  end

  defp save(provider, credentials) do
    File.mkdir_p!(Path.dirname(@auth_path))

    auth =
      case File.read(@auth_path) do
        {:ok, text} -> Jason.decode!(text)
        _ -> %{}
      end

    File.write!(@auth_path, Jason.encode!(Map.put(auth, provider, credentials), pretty: true))
  end

  defp account_id(jwt) do
    with [_header, payload, _sig] <- String.split(jwt, "."),
         {:ok, json} <- payload |> base64url_decode() |> Jason.decode() do
      get_in(json, [@claim_path, "chatgpt_account_id"])
    else
      _ -> nil
    end
  end

  defp pkce_challenge(verifier), do: verifier |> then(&:crypto.hash(:sha256, &1)) |> base64url()
  defp random_urlsafe(bytes), do: bytes |> :crypto.strong_rand_bytes() |> base64url()
  defp base64url(binary), do: Base.url_encode64(binary, padding: false)

  defp base64url_decode(value) do
    padding = String.duplicate("=", rem(4 - rem(byte_size(value), 4), 4))
    Base.url_decode64!(value <> padding, padding: true)
  end

  defp atomize_keys(map) do
    map
    |> Map.take(["access", "refresh", "expires", "accountId", "account_id", "type"])
    |> Map.new(fn
      {"access", value} -> {:access, value}
      {"refresh", value} -> {:refresh, value}
      {"expires", value} -> {:expires, value}
      {"accountId", value} -> {:accountId, value}
      {"account_id", value} -> {:account_id, value}
      {"type", value} -> {:type, value}
    end)
  end
end
