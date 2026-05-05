defmodule Exy.Model.Direct do
  @moduledoc "Direct LLM generation bypassing the Jido agent loop."

  alias Exy.Model.Content
  alias ReqLLM.Message.ContentPart

  @type prompt :: String.t() | [Content.t() | ContentPart.t()]

  @spec ask(prompt(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(prompt, opts \\ []) when is_binary(prompt) or is_list(prompt) do
    {model, messages, session_id, request_opts} = request(prompt, opts)

    record_request(prompt, model, session_id)
    result = ReqLLM.generate_text(model, messages, request_opts)
    record_response(result, session_id)
    result
  end

  @spec stream(prompt(), keyword()) :: {:ok, term()} | {:error, term()}
  def stream(prompt, opts \\ []) when is_binary(prompt) or is_list(prompt) do
    {model, messages, session_id, request_opts} = request(prompt, opts)

    callback_opts =
      Keyword.take(opts, [:on_chunk, :on_meta, :on_result, :on_thinking, :on_tool_call])

    record_request(prompt, model, session_id)

    with {:ok, request_opts} <-
           Exy.Model.Transport.prepare_stream_opts(model, request_opts, session_id),
         {:ok, response} <- ReqLLM.stream_text(model, messages, request_opts),
         {:ok, final_response} <- ReqLLM.StreamResponse.process_stream(response, callback_opts) do
      result = {:ok, final_response}
      record_response(result, session_id)
      result
    else
      {:error, _reason} = error ->
        record_response(error, session_id)
        error
    end
  end

  defp request(prompt, opts) do
    model = Exy.Model.Config.resolve(opts)
    system = Keyword.get_lazy(opts, :system, &Exy.Prompts.system/0)

    messages = [
      ReqLLM.Context.system(system),
      ReqLLM.Context.user(to_req_llm_content(prompt))
    ]

    session_id = Keyword.get_lazy(opts, :session_id, &Exy.Session.Store.new_id/0)

    {reqllm_model, provider_opts} = resolve_model_with_auth(model)

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
      |> Keyword.merge(provider_opts)
      |> maybe_put_openrouter_session(model, session_id)

    {reqllm_model, messages, session_id, request_opts}
  end

  defp maybe_put_openrouter_session(opts, "openrouter:" <> _model, session_id),
    do: Keyword.put_new(opts, :session_id, session_id)

  defp maybe_put_openrouter_session(opts, _model, _session_id), do: opts

  defp resolve_model_with_auth(model) do
    case Exy.Auth.Provider.for_model(model) do
      {module, prefix, model_id} ->
        {reqllm_model, resolve_opts} = module.resolve_model(prefix, model_id)
        {reqllm_model, Keyword.merge(resolve_opts, module.request_options())}

      nil ->
        {model, []}
    end
  end

  defp to_req_llm_content(prompt) when is_binary(prompt), do: prompt

  defp to_req_llm_content(prompt) when is_list(prompt), do: Content.to_req_llm_parts(prompt)

  defp record_request(prompt, model, session_id) do
    Exy.Session.Store.append_trajectory(
      :user_message,
      %{prompt: Content.summarize(prompt), model: model},
      session_id: session_id
    )
  end

  defp record_response({:ok, response}, session_id) do
    Exy.Session.Store.append_trajectory(:assistant_message, %{result: response},
      session_id: session_id
    )

    if usage = Exy.Model.Usage.from_response(response) do
      Exy.Session.Store.append_trajectory(:llm_usage, usage, session_id: session_id)
    end
  end

  defp record_response({:error, reason}, session_id) do
    Exy.Session.Store.append_trajectory(:assistant_message, %{error: inspect(reason)},
      session_id: session_id
    )
  end
end
