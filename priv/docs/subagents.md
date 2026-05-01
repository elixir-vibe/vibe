# Subagents

Subagents are supervised jobs. LLM subagents create child Exy sessions, so their work can be inspected or attached like any other session.

```elixir
{:ok, job} = Exy.Subagents.start("Research ReqLLM OpenRouter support", role: :scout)
Exy.Subagents.status(job.id)
Exy.Subagents.await(job.id)
Exy.Subagents.result(job.id)
Exy.Subagents.cancel(job.id)
```

Attach to a child session from the shell:

```bash
exy a <job.child_session_id>
```

Run one-off or parallel work:

```elixir
Exy.Subagents.ask("Summarize this repository", role: :summarizer)

Exy.Subagents.run_many([
  %{role: :scout, task: "Inspect provider docs"},
  %{role: :reviewer, task: "Review the implementation plan"}
])
```

Schedule background work:

```elixir
{:ok, schedule} = Exy.Subagents.schedule("Check telemetry errors", every: :timer.minutes(30))
Exy.Subagents.scheduled()
Exy.Subagents.unschedule(schedule.id)
```

Subagents should report findings to their parent session instead of writing global memory directly.
