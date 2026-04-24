defmodule Exy.Agent.Coding do
  @moduledoc """
  Minimal Jido.AI ReAct agent wired to Exy's three Elixir tools.
  """

  @system_prompt Exy.SystemPrompt.default()

  use Jido.AI.Agent,
    name: "exy_coding_agent",
    model: :exy,
    tools: [Exy.Actions.Eval, Exy.Actions.AST, Exy.Actions.LSP],
    system_prompt: @system_prompt
end
