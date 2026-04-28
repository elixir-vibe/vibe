defmodule Exy.Agent.Coding do
  @moduledoc """
  Minimal Jido.AI ReAct agent wired to Exy's coding tools.
  """

  @practical_max_iterations 2_147_483_647
  @tool_timeout_ms 86_400_000
  @stream_timeout_ms 86_460_000

  @doc "Named value mirrored into the Jido.AI macro's literal max_iterations option."
  def practical_max_iterations, do: @practical_max_iterations

  @doc "Named value mirrored into the Jido.AI macro's literal tool_timeout_ms option."
  def tool_timeout_ms, do: @tool_timeout_ms

  @doc "Named value mirrored into the Jido.AI macro's literal stream_timeout_ms option."
  def stream_timeout_ms, do: @stream_timeout_ms

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
    # requires compile-time literal options, so mirror practical_max_iterations/0.
    max_iterations: 2_147_483_647,
    # Tool calls may intentionally run project generators, dependency installs,
    # or long test suites. Keep this finite so cancellation still has a ceiling,
    # but high enough that eval/Exy.Command own normal command timeouts.
    tool_timeout_ms: 86_400_000,
    stream_timeout_ms: 86_460_000,
    plugins: [Exy.Agent.Streaming.Plugin],
    system_prompt: false
end
