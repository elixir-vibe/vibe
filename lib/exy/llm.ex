defmodule Exy.LLM do
  @moduledoc """
  Thin ReqLLM facade for one-shot model calls.

  Jido.AI is used for supervised/tool-using agents; ReqLLM remains the simple
  provider abstraction for direct calls and smoke tests.
  """

  @default_system """
  You are Exy, a concise Elixir-centric coding agent.
  Prefer elixir_eval for BEAM/runtime work, elixir_ast for Elixir syntax, and elixir_lsp for Expert diagnostics/navigation.
  """

  @spec ask(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(prompt, opts \\ []) when is_binary(prompt) do
    model = Exy.LLM.Model.resolve(opts)
    system = Keyword.get(opts, :system, @default_system)

    messages = [
      ReqLLM.Context.system(system),
      ReqLLM.Context.user(prompt)
    ]

    session_id = Keyword.get_lazy(opts, :session_id, &Exy.Session.new_id/0)
    request_opts = Keyword.drop(opts, [:model, :system, :session_id])

    record_request(prompt, model, session_id)
    result = ReqLLM.generate_text(model, messages, request_opts)
    record_response(result, session_id)
    result
  end

  defp record_request(prompt, model, session_id) do
    Exy.Trajectory.Store.append(:user_message, %{prompt: prompt, model: model},
      session_id: session_id
    )
  end

  defp record_response({:ok, response}, session_id) do
    Exy.Trajectory.Store.append(:assistant_message, %{result: response}, session_id: session_id)

    if usage = Exy.LLM.Usage.from_response(response) do
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
    :ok
  end
end
