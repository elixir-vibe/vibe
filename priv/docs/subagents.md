# Subagents

Subagents are supervised jobs. LLM subagents create child Vibe sessions, so their work can be inspected or attached like any other session.

```elixir
{:ok, job} = Vibe.Subagents.start("Review the storage search code")
Vibe.Subagents.status(job.id)
Vibe.Subagents.await(job.id)
Vibe.Subagents.result(job.id)
Vibe.Subagents.cancel(job.id)
```

Inspect jobs from the CLI:

```bash
vibe subagents jobs
vibe subagents status <job-id>
vibe subagents result <job-id>
vibe subagents cancel <job-id>
```

Attach to a child session from the shell:

```bash
vibe a <job.child_session_id>
```

Run one-off or parallel work:

```elixir
Vibe.Subagents.ask("Summarize this repository")

Vibe.Subagents.run_many([
  %{task: "Inspect provider docs"},
  %{task: "Review the implementation plan"}
])
```

Pass `role: :coder` or another profile when you have configured the matching model/provider credentials.

Schedule background work:

```elixir
{:ok, schedule} = Vibe.Subagents.schedule("Check telemetry errors", every: :timer.minutes(30))
Vibe.Subagents.scheduled()
Vibe.Subagents.unschedule(schedule.id)
```

Subagents should report findings to their parent session instead of writing global memory directly.
