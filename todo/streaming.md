# Streaming TODO

## Jido.AI multimodal ReAct queries

- Track `agentjido/jido_ai#278` (`feat: support multimodal ReAct queries`).
  - Adds a bounded `Jido.AI.Query` contract for `String.t() | [ReqLLM.Message.ContentPart.t()]`.
  - Allows ReAct request, runner, and action entrypoints to accept ReqLLM content parts directly.
  - Preserves multimodal user entries through `Jido.AI.Context` and request projection.
  - Summarizes multimodal queries for runtime event metadata while sending full content to ReqLLM.
- After it lands and Vibe updates to a Jido.AI version that includes it:
  - Remove or reduce `tool_context[:semantic_prompt_content]` prompt-image side channel.
  - Pass semantic prompt content directly into `Vibe.ask/3` / Jido where supported.
  - Keep `Vibe.Agent.ImageRequestTransformer` only for tool-result image follow-ups if still needed.
  - Run `VIBE_REAL_MODEL=1 mix run scripts/image_agent_smoke.exs` before and after removing the workaround.

## Upstream stream-ordering metadata

- Track `agentjido/jido_ai#271` (`fix: preserve LLM delta ordering metadata`).
  - Branch has been rebased onto current `agentjido/jido_ai:main` and conflicts were resolved.
  - `mix quality` passed on the rebased branch.
  - After it lands and Vibe updates to a Jido.AI version that includes `seq` on `ai.llm.delta`, revisit `Vibe.Agent.Streaming`:
    - Keep the current ReAct runtime-event ordering path until the dependency update is verified in a long live session trace.
    - Add/keep regression coverage for out-of-order stream delivery using sequence metadata.
    - Decide whether derived `ai.llm.delta` with `seq` can replace direct `ai.react.worker.event` consumption, or whether Vibe should continue preferring runtime events for richer metadata.
    - Remove any compatibility code only after `runtime_text`, `ui_text`, and final response text match across a long deterministic trace with observed arrival inversions.

## Persistent Responses WebSocket agent loops

- Track ReqLLM PR `agentjido/req_llm#663` (`feat: support reusable Responses WebSocket sessions`).
  - Adds caller-owned reusable OpenAI Responses WebSocket sessions.
  - Adds Codex WebSocket support for the ChatGPT backend shape used by Vibe credentials.
  - Verified with Vibe Codex OAuth credentials:
    - SSE sanity: `TEXT="codex-ok"`
    - WebSocket: `TEXT="codex-ws-ok"`
    - Reused WebSocket session: `first-reuse-ok`, `second-reuse-ok`, `SESSION_ALIVE_AFTER_TWO=true`
  - `mix quality` passed.
- Track Jido.AI PR `agentjido/jido_ai#272` (`feat: reuse OpenAI Responses WebSocket sessions`).
  - Adds optional ReAct support for one Responses WebSocket per run using:
    ```elixir
    llm_opts: [
      provider_options: [
        openai_stream_transport: :websocket,
        openai_reuse_websocket: true
      ]
    ]
    ```
  - Supports both `openai:` and `openai_codex:` model specs.
  - Verified live with local ReqLLM branch and Vibe Codex OAuth credentials: `%{result: "jido-codex-ws-ok"}`.
  - `mix quality` passed.
- After both PRs land:
  - Update Vibe dependencies to the released/merged ReqLLM and Jido.AI commits.
  - Add Vibe profile/config support for opting into persistent Responses WebSocket loops for `openai_codex:gpt-5.5`.
  - Run a real Vibe session with tool calls and `VIBE_STREAM_TRACE_DIR` enabled to verify:
    - no duplicate stream deltas
    - ordered assistant text still matches final response text
    - persistent socket survives at least two model turns in a tool loop
    - socket closes when the Vibe/Jido run exits or is cancelled
  - Keep default transport conservative until live traces show stable behavior across normal and cancellation paths.
