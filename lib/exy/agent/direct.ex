defmodule Exy.Agent.Direct do
  @moduledoc false

  @spec ask(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(prompt, opts \\ []) when is_binary(prompt) do
    {model, messages, session_id, request_opts} = request(prompt, opts)

    record_request(prompt, model, session_id)
    result = ReqLLM.generate_text(model, messages, request_opts)
    record_response(result, session_id)
    result
  end

  @spec stream(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def stream(prompt, opts \\ []) when is_binary(prompt) do
    {model, messages, session_id, request_opts} = request(prompt, opts)

    callback_opts =
      Keyword.take(opts, [:on_chunk, :on_meta, :on_result, :on_thinking, :on_tool_call])

    record_request(prompt, model, session_id)

    with {:ok, response} <- ReqLLM.stream_text(model, messages, request_opts),
         {:ok, final_response} <- ReqLLM.StreamResponse.process_stream(response, callback_opts) do
      result = {:ok, final_response}
      record_response(result, session_id)
      result
    end
  end

  defp request(prompt, opts) do
    model = Exy.Agent.Model.resolve(opts)
    system = Keyword.get_lazy(opts, :system, &Exy.SystemPrompt.default/0)

    messages = [
      ReqLLM.Context.system(system),
      ReqLLM.Context.user(prompt)
    ]

    session_id = Keyword.get_lazy(opts, :session_id, &Exy.Session.Store.new_id/0)

    request_opts =
      opts
      |> Keyword.drop([
        :model,
        :system,
        :session_id,
        :on_chunk,
        :on_meta,
        :on_result,
        :on_thinking,
        :on_tool_call
      ])
      |> maybe_put_codex_credentials(model)

    {model, messages, session_id, request_opts}
  end

  defp maybe_put_codex_credentials(opts, "openai_codex:" <> _model) do
    case Application.get_env(:exy, :openai_codex_credentials) do
      %{access: access} = credentials when is_binary(access) ->
        opts
        |> Keyword.put_new(:access_token, access)
        |> maybe_put_chatgpt_account_id(credentials)

      _credentials ->
        opts
    end
  end

  defp maybe_put_codex_credentials(opts, _model), do: opts

  defp maybe_put_chatgpt_account_id(opts, %{accountId: account_id}) when is_binary(account_id),
    do: Keyword.put_new(opts, :chatgpt_account_id, account_id)

  defp maybe_put_chatgpt_account_id(opts, %{account_id: account_id}) when is_binary(account_id),
    do: Keyword.put_new(opts, :chatgpt_account_id, account_id)

  defp maybe_put_chatgpt_account_id(opts, _credentials), do: opts

  defp record_request(prompt, model, session_id) do
    Exy.Trajectory.Store.append(:user_message, %{prompt: prompt, model: model},
      session_id: session_id
    )
  end

  defp record_response({:ok, response}, session_id) do
    Exy.Trajectory.Store.append(:assistant_message, %{result: response}, session_id: session_id)

    if usage = Exy.Agent.Usage.from_response(response) do
      Exy.Trajectory.Store.append(:llm_usage, usage, session_id: session_id)
    end
  end

  defp record_response({:error, reason}, session_id) do
    Exy.Trajectory.Store.append(:assistant_message, %{error: inspect(reason)},
      session_id: session_id
    )
  end

  @spec put_codex_credentials(map()) :: :ok
  def put_codex_credentials(%{access: access} = credentials) when is_binary(access) do
    ReqLLM.put_key(:openai_codex_api_key, access)
    Application.put_env(:exy, :openai_codex_credentials, credentials)
    Application.put_env(:req_llm, :oauth_file, Exy.Paths.auth_file())
    :ok
  end
end
