defmodule Vibe.Auth.Codex do
  @moduledoc """
  ChatGPT/Codex OAuth login compatible with pi's OpenAI Codex flow.
  """

  @behaviour Vibe.Auth.Provider

  @client_id "app_EMoamEEZ73f0CkXaXp7hrann"
  @authorize_url "https://auth.openai.com/oauth/authorize"
  @token_url "https://auth.openai.com/oauth/token"
  @redirect_uri "http://localhost:1455/auth/callback"
  @scope "openid profile email offline_access"
  @claim_path "https://api.openai.com/auth"
  @oauth_callback_timeout_ms 180_000
  @refresh_before_expiry_ms 60_000
  @seconds_to_milliseconds 1_000
  alias Vibe.Auth.Codex.CallbackServer
  alias Vibe.Auth.Store

  @impl Vibe.Auth.Provider
  def id, do: "openai-codex"

  @impl Vibe.Auth.Provider
  def model_prefixes, do: ["openai_codex"]

  @impl Vibe.Auth.Provider
  def resolve_model(_prefix, model_id), do: {"openai_codex:#{model_id}", []}

  @impl Vibe.Auth.Provider
  def request_options do
    case Application.get_env(:vibe, :openai_codex_credentials) do
      %{access: access} = creds when is_binary(access) ->
        opts = [access_token: access]

        case creds[:accountId] || creds[:account_id] do
          id when is_binary(id) -> [{:chatgpt_account_id, id} | opts]
          _ -> opts
        end

      _ ->
        []
    end
  end

  @impl Vibe.Auth.Provider
  @spec login(keyword()) :: {:ok, map()} | {:error, term()}
  def login(opts \\ []) do
    verifier = random_urlsafe(64)
    challenge = pkce_challenge(verifier)
    state = random_urlsafe(24)
    url = authorize_url(challenge, state, Keyword.get(opts, :originator, "vibe"))

    with {:ok, server} <- CallbackServer.start_link(state) do
      maybe_open_browser(url, opts)
      print_login_instructions(url, opts)

      code =
        CallbackServer.wait_for_code(
          server,
          Keyword.get(opts, :timeout, @oauth_callback_timeout_ms)
        ) ||
          maybe_prompt_code(state, opts)

      CallbackServer.stop(server)

      with {:ok, code} <- authorization_code(code),
           {:ok, credentials} <- exchange_code(code, verifier),
           {:ok, credentials} <- attach_account_id(credentials) do
        credentials = Map.put(credentials, :type, "oauth")
        Store.save(id(), credentials)
        put_credentials(credentials)
        IO.puts("Signed in with ChatGPT/Codex.")
        {:ok, login_result(credentials)}
      else
        {:error, reason} = error ->
          IO.puts(:stderr, "ChatGPT/Codex sign-in failed: #{format_error(reason)}")
          error
      end
    end
  end

  defp print_login_instructions(url, opts) do
    unless Keyword.get(opts, :quiet, false) do
      IO.puts("Open this URL to sign in with ChatGPT/Codex:\n\n#{url}\n")
      IO.puts("Waiting on #{@redirect_uri} ...")
    end
  end

  @impl Vibe.Auth.Provider
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

  @impl Vibe.Auth.Provider
  @spec load() :: {:ok, map()} | {:error, :not_found | term()}
  def load, do: load(id())

  @spec load(String.t()) :: {:ok, map()} | {:error, :not_found | term()}
  def load(provider) do
    with {:ok, credentials} <- Store.load(provider) do
      {:ok, atomize_keys(credentials)}
    end
  end

  @impl Vibe.Auth.Provider
  @spec usage(keyword()) :: {:ok, map()} | {:error, term()}
  def usage(opts \\ []), do: Vibe.Codex.Usage.limits(opts)

  @spec usage_limits(keyword()) :: {:ok, map()} | {:error, term()}
  def usage_limits(opts \\ []), do: usage(opts)

  @impl Vibe.Auth.Provider
  @spec ensure_fresh() :: {:ok, map()} | {:error, term()}
  def ensure_fresh do
    with {:ok, credentials} <- load() do
      if Map.get(credentials, :expires, 0) <
           System.system_time(:millisecond) + @refresh_before_expiry_ms do
        with {:ok, refreshed} <- refresh(credentials) do
          Store.save(id(), refreshed)
          put_credentials(refreshed)
          {:ok, refreshed}
        end
      else
        put_credentials(credentials)
        {:ok, credentials}
      end
    end
  end

  @impl Vibe.Auth.Provider
  @spec put_credentials(map()) :: :ok
  def put_credentials(%{access: access} = credentials) when is_binary(access) do
    ReqLLM.put_key(:openai_codex_api_key, access)
    Application.put_env(:vibe, :openai_codex_credentials, credentials)
    Application.put_env(:req_llm, :oauth_file, Vibe.Paths.auth_file())
    :ok
  end

  defp login_result(credentials) do
    %{
      provider: id(),
      account_id: credentials[:accountId],
      expires: credentials[:expires]
    }
  end

  defp format_error(reason), do: inspect(reason, pretty: true)

  defp authorization_code(code) when is_binary(code) and code != "", do: {:ok, code}
  defp authorization_code(_code), do: {:error, :authorization_code_missing}

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
       expires: System.system_time(:millisecond) + expires_in * @seconds_to_milliseconds
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

  defp maybe_prompt_code(state, opts) do
    if Keyword.get(opts, :prompt_code, true), do: prompt_code(state)
  end

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
