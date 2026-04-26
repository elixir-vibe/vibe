defmodule Exy.Agent.Coding do
  @moduledoc """
  Minimal Jido.AI ReAct agent wired to Exy's coding tools.
  """

  use Jido.AI.Agent,
    name: "exy_coding_agent",
    model: :exy,
    tools: [
      Exy.Actions.Read,
      Exy.Actions.Write,
      Exy.Actions.Edit,
      Exy.Actions.Eval,
      Exy.Actions.AST,
      Exy.Actions.LSP
    ],
    plugins: [Exy.Agent.Streaming.Plugin],
    system_prompt: false
end
