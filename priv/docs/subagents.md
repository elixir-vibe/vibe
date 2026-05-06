# Subagents

Subagents are supervised jobs. LLM subagents create child Vibe sessions, so their work can be inspected or attached like any other session.

```elixir
{:ok, job} = Vibe.Subagents.start("Research ReqLLM OpenRouter support", role: :scout)
Vibe.Subagents.status(job.id)
Vibe.Subagents.await(job.id)
Vibe.Subagents.result(job.id)
Vibe.Subagents.cancel(job.id)
```

Attach to a child session from the shell:

```bash
vibe a <job.child_session_id>
```

Run one-off or parallel work:

```elixir
Vibe.Subagents.ask("Summarize this repository", role: :summarizer)

Vibe.Subagents.run_many([
  %{role: :scout, task: "Inspect provider docs"},
  %{role: :reviewer, task: "Review the implementation plan"}
])
```

Schedule background work:

```elixir
{:ok, schedule} = Vibe.Subagents.schedule("Check telemetry errors", every: :timer.minutes(30))
Vibe.Subagents.scheduled()
Vibe.Subagents.unschedule(schedule.id)
```

Subagents should report findings to their parent session instead of writing global memory directly.
