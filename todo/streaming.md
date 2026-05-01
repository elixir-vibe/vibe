# Streaming TODO

- After `agentjido/jido_ai#271` lands and Exy updates to a Jido.AI version that includes `seq` on `ai.llm.delta`, revisit `Exy.Agent.Streaming`:
  - Keep the current ReAct runtime-event ordering path until the dependency update is verified in a long live session trace.
  - Add/keep regression coverage for out-of-order stream delivery using sequence metadata.
  - Decide whether derived `ai.llm.delta` with `seq` can replace direct `ai.react.worker.event` consumption, or whether Exy should continue preferring runtime events for richer metadata.
  - Remove any compatibility code only after `runtime_text`, `ui_text`, and final response text match across a long deterministic trace with observed arrival inversions.
