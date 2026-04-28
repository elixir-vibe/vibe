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
    # Exy sessions are long-lived and can span days or weeks. Jido.AI currently
    # requires a positive integer here, so use a practically unreachable ceiling
    # instead of the upstream default of 10 tool iterations.
    max_iterations: 2_147_483_647,
    # Tool calls may intentionally run project generators, dependency installs,
    # or long test suites. Keep this finite so cancellation still has a ceiling,
    # but high enough that eval/Exy.Command own normal command timeouts.
    tool_timeout_ms: 86_400_000,
    stream_timeout_ms: 86_460_000,
    plugins: [Exy.Agent.Streaming.Plugin],
    system_prompt: false
end
