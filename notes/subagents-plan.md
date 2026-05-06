# Subagents / OpenRouter / Agent Profiles Plan

## Decisions

- OpenRouter is just another ReqLLM provider.
  - Support means auth provider + credential loading for `openrouter:*` models.
  - No OpenRouter-specific agent architecture.
- Roles are user-editable profiles, not hardcoded Pi-style classes.
  - Any explicit `model`, `system`, or `tools` on a task overrides the role profile.
  - Unknown explicit roles should error unless a model/system is fully provided.
- Agent and subagent execution should share the same primitive agent API.
  - `Vibe.Agent` owns one-agent model interaction.
  - `Vibe.Subagents` owns orchestration, parent/child sessions, background jobs, schedules, and memory semantics.
- Every LLM subagent gets a real `Vibe.Session` so users can attach with `vibe a <child-session-id>`.
  - Optional convenience later: `vibe a <job-id>` resolves to the child session.
- Running subagent sessions are observable/read-only by default for determinism.
  - After completion they can become normal interactive sessions.
  - Later option: `interactive: true`.
- Background/scheduled agents use OTP supervision first, not Oban.
  - Add a scheduler backend behaviour so Oban can be added later for Phoenix/hosted deployments.
  - Default local scheduler persists schedules under `~/.vibe` and skips missed runs by default.
- Do not automatically retry LLM jobs.
  - Model calls and tool/file side effects are not idempotent by default.
  - Retries must be explicit.
- Memory scopes stay separate.
  - `Vibe.Eval`: per-session shell/eval state.
  - `Vibe.Agent.Memory`: ephemeral per-agent/subagent runtime state.
  - `Vibe.Memory`: curated durable user/global/workspace/session memory.
  - Subagents read higher scopes, but writes upward go through parent/delegation hooks unless explicitly configured.

## Supervision tree target

```text
Vibe.Supervisor
├─ Registry Vibe.Registry
├─ Vibe.Telemetry
├─ Jido
├─ Vibe.Jido
├─ Vibe.SessionSupervisor                 DynamicSupervisor
├─ Vibe.Agent.Supervisor                   DynamicSupervisor
├─ Vibe.Subagents.Supervisor               Supervisor
│  ├─ Vibe.Subagents.Manager               GenServer
│  ├─ Vibe.Subagents.JobSupervisor         DynamicSupervisor
│  └─ Vibe.Subagents.Scheduler             GenServer/backend wrapper
├─ Vibe.Plugin.Supervisor                  DynamicSupervisor
├─ Vibe.Memory.Manager
├─ Vibe.Agent.Memory
├─ Vibe.Eval.Supervisor                    DynamicSupervisor
├─ Vibe.Code.LSP.Supervisor
├─ Vibe.Terminal.Supervisor
├─ Vibe.UI.Bus
└─ Vibe.Session.Processes
```

## Process ownership

### `Vibe.Session`

Owns:
- canonical chat/UI state
- subscribers
- durable UI/session events
- foreground prompt dispatch

Does not own:
- subagent process lifetime
- scheduler timers
- global memory provider lifecycle

### `Vibe.Agent`

Owns:
- primitive one-agent API
- model/provider credential setup
- starting/asking a Jido-backed coding agent

Should expose:

```elixir
Vibe.Agent.ask(prompt, opts)
```

for one-shot use by sessions/subagents.

### `Vibe.Agent.Supervisor`

Dynamic supervisor for Jido/agent processes.

Restart policy:
- `:temporary` children.
- No blind automatic restarts that duplicate model calls.

### `Vibe.Subagents.Supervisor`

Static supervisor for the subagent subsystem.

Children:
- `Vibe.Subagents.Manager`
- `Vibe.Subagents.JobSupervisor`
- `Vibe.Subagents.Scheduler`

Restart strategy:
- `:one_for_one`

### `Vibe.Subagents.Manager`

Owns control-plane metadata:
- start job
- list jobs
- status
- cancel
- await/result
- parent notification
- reconstruct active jobs from Registry after manager restart

Restart policy:
- permanent

### `Vibe.Subagents.Job`

One process per subagent run.

Owns:
- job id
- child session id
- role/profile resolution at job start
- model/system/tools for this job
- agent start/cancel
- timeout
- start/finish persistence
- memory delegation hook

Restart policy:
- temporary
- failure becomes failed job; no automatic rerun

### `Vibe.Subagents.Scheduler`

Owns timers and schedule definitions.

Responsibilities:
- schedule one-shot and recurring subagent jobs
- persist schedule create/cancel events
- reload schedules on restart
- skip missed runs by default

Restart policy:
- permanent

## Public APIs target

### Agent primitive

```elixir
Vibe.Agent.ask(prompt, opts \\ [])
```

Important opts:

```elixir
session_id: binary()
agent_id: binary()
role: atom()
model: binary()
system: binary()
tools: :default | [module()]
tool_context: map()
```

### Agent profiles

File:

```text
~/.vibe/agent-profiles.toml
```

Use explicit `{:toml, "~> 0.7"}` dependency.

Example:

```toml
default_model = "openai_codex:gpt-5.5"

[providers.openrouter]
app_title = "Vibe"
app_referer = "https://github.com/elixir-vibe/vibe"

[roles.scout]
model = "openrouter:anthropic/claude-3.5-haiku"
system = "Find facts. Do not edit files."
tools = ["read", "eval"]

[roles.coder]
model = "openai_codex:gpt-5.5"
system = "Implement minimal changes and validate."
tools = ["read", "write", "edit", "eval", "ast", "lsp"]

[roles.reviewer]
model = "openrouter:anthropic/claude-sonnet-4"
system = "Review correctness, maintainability, and risks. Do not edit files."
tools = ["read", "eval", "ast", "lsp"]
```

APIs:

```elixir
Vibe.Agent.Profile.path()
Vibe.Agent.Profile.ensure!()
Vibe.Agent.Profile.load()
Vibe.Agent.Profile.role(:scout)
Vibe.Agent.Profile.model_for(role: :scout)
Vibe.Agent.Profile.system_for(role: :reviewer)
Vibe.Agent.Profile.tools_for(role: :coder)
Vibe.Agent.Profile.provider_options(:openrouter)
```

### Subagents

Sync ask:

```elixir
Vibe.Subagents.ask("Research ReqLLM OpenRouter support",
  role: :researcher,
  parent_session_id: session_id
)
```

Background job:

```elixir
{:ok, job} =
  Vibe.Subagents.start("Monitor telemetry errors",
    role: :monitor,
    parent_session_id: session_id
  )
```

Many:

```elixir
Vibe.Subagents.run_many([
  %{role: :researcher, task: "Inspect ReqLLM OpenRouter docs"},
  %{role: :architect, task: "Design subagent memory semantics"},
  %{role: :reviewer, task: "Review risks"}
], parent_session_id: session_id, max_concurrency: 3)
```

Job control:

```elixir
Vibe.Subagents.jobs()
Vibe.Subagents.status(job_id)
Vibe.Subagents.cancel(job_id)
Vibe.Subagents.result(job_id)
Vibe.Subagents.await(job_id, timeout)
```

Schedule:

```elixir
Vibe.Subagents.schedule("Check telemetry errors",
  role: :monitor,
  every: :timer.minutes(30),
  parent_session_id: session_id,
  missed: :skip
)

Vibe.Subagents.scheduled()
Vibe.Subagents.unschedule(schedule_id)
```

## Subagent session / attach semantics

- Each LLM subagent creates a real child `Vibe.Session`.
- Job metadata links:

```elixir
%{
  job_id: job_id,
  child_session_id: child_session_id,
  parent_session_id: parent_session_id
}
```

- User can attach:

```bash
vibe a <child-session-id>
```

- Parent UI should show job id + child session id + attach command.
- Running child session should be read-only by default.
- Finished child session may be continued interactively later.

## Scheduler backend design

Define backend behaviour so local scheduler can later be swapped for Oban.

```elixir
defmodule Vibe.Subagents.Scheduler.Backend do
  @callback schedule(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  @callback unschedule(String.t()) :: :ok | {:error, term()}
  @callback list() :: [term()]
end
```

Default backend:
- `Vibe.Subagents.Scheduler.Local`
- uses OTP timers
- persists schedule events under `~/.vibe/subagents/schedules.jsonl`
- skips missed runs by default

Future backend:
- `Vibe.Subagents.Scheduler.Oban`
- for Phoenix/hosted Vibe with Postgres/Ecto/Oban
- default `max_attempts: 1`

## OpenRouter implementation details

- `Vibe.Auth.OpenRouter` only handles API key.
- Register provider aliases:
  - `openrouter`
  - maybe `open-router`
- Load from auth store or `OPENROUTER_API_KEY`.
- Put key with:

```elixir
ReqLLM.put_key(:openrouter_api_key, key)
```

- `Vibe.Agent.ensure_provider_credentials/1` detects provider prefix generically where possible.
- OpenRouter provider options come from agent profile provider options or explicit call opts.

## Implementation phases

1. Add `toml` direct dependency and `Vibe.Agent.Profile`.
2. Add `Vibe.Auth.OpenRouter` as boring provider support.
3. Add `Vibe.Agent.ask/2` primitive and role/profile option resolution.
4. Refactor subagents supervision tree:
   - `Vibe.Subagents.Supervisor`
   - `Vibe.Subagents.Manager`
   - `Vibe.Subagents.JobSupervisor`
   - `Vibe.Subagents.Job`
5. Make LLM subagents create real child sessions and stream there.
6. Rebuild `Vibe.Subagents.run_many/2` on top of supervised jobs.
7. Add background job APIs.
8. Add local scheduler with persisted schedule definitions.
9. Add CLI visibility/attach helpers:
   - list subagent jobs
   - show child session ids
   - optionally resolve job id in `vibe a <job-id>`.

## Validation expectations

After each phase:

```bash
mix test <focused tests>
mix ci
MIX_ENV=prod mix compile --warnings-as-errors
```

No automatic retries for model calls in tests. Use fake ask functions for subagent tests.
