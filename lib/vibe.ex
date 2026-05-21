defmodule Vibe do
  @moduledoc """
  Minimal BEAM-native coding-agent substrate.

  Vibe intentionally keeps the model-facing surface small:

    * `Vibe.Eval.run/2` for runtime Elixir expressions
    * `Vibe.Code.AST.run/1` for ExAST search/replace/diff
    * `Vibe.Code.LSP.run/1` for Expert/LSP operations
    * shell/file operations live at the client layer

  Rich capabilities are exposed as normal Elixir modules callable from
  `Vibe.Eval`: `Vibe.OTP`, `Vibe.Profiler`, `Vibe.Skill`, `Vibe.Subagents`,
  `Vibe.Context`, and `Vibe.SelfPatch`.
  """

  @type agent_ref :: pid() | atom() | {:via, module(), term()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    Vibe.Application.configure_dependency_logging()
    Application.ensure_all_started(:vibe)
    Vibe.Agent.start_link(opts)
  end

  @spec ask(agent_ref(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(agent, prompt, opts \\ []), do: Vibe.Agent.ask_sync(agent, prompt, opts)

  @spec ask!(agent_ref(), String.t(), keyword()) :: term()
  def ask!(agent, prompt, opts \\ []) do
    case ask(agent, prompt, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "Vibe ask failed: #{inspect(reason)}"
    end
  end

  @spec supervision_tree(keyword()) :: map() | nil
  def supervision_tree(opts \\ []), do: Vibe.OTP.supervision_tree(Vibe.Supervisor, opts)
end
