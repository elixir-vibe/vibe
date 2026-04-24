defmodule Exy do
  @moduledoc """
  Minimal BEAM-native coding-agent substrate.

  Exy intentionally keeps the model-facing surface small:

    * `Exy.Eval.run/2` for runtime Elixir expressions
    * `Exy.AST.run/1` for ExAST search/replace/diff
    * `Exy.LSP.run/1` for Expert/LSP operations
    * shell/file operations live at the client layer

  Rich capabilities are exposed as normal Elixir modules callable from
  `Exy.Eval`: `Exy.OTP`, `Exy.Profile`, `Exy.Skill`, `Exy.Subagents`,
  `Exy.Trajectory`, and `Exy.SelfPatch`.
  """

  @type agent_ref :: pid() | atom() | {:via, module(), term()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: Exy.Agent.start_link(opts)

  @spec ask(agent_ref(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def ask(agent, prompt, opts \\ []), do: Exy.Agent.ask_sync(agent, prompt, opts)

  @spec ask!(agent_ref(), String.t(), keyword()) :: term()
  def ask!(agent, prompt, opts \\ []) do
    case ask(agent, prompt, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "Exy ask failed: #{inspect(reason)}"
    end
  end

  @spec supervision_tree(keyword()) :: map() | nil
  def supervision_tree(opts \\ []), do: Exy.OTP.supervision_tree(Exy.Supervisor, opts)
end
