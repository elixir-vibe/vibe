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

  @spec ask(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def ask(prompt, opts \\ []) when is_binary(prompt) do
    model = Keyword.get(opts, :model, System.get_env("EXY_MODEL") || "openai:gpt-4o-mini")
    system = Keyword.get(opts, :system, @default_system)

    messages = [
      ReqLLM.Context.system(system),
      ReqLLM.Context.user(prompt)
    ]

    opts = Keyword.drop(opts, [:model, :system])
    ReqLLM.generate_text(model, messages, opts)
  end

  @spec put_codex_credentials(map()) :: :ok
  def put_codex_credentials(%{access: access} = credentials) when is_binary(access) do
    ReqLLM.put_key(:openai_codex_api_key, access)
    Application.put_env(:exy, :openai_codex_credentials, credentials)
    :ok
  end
end
