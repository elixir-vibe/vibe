# Storage

Vibe stores durable local state in SQLite through Ecto. The default database path is:

```text
~/.vibe/vibe.db
```

Stored state includes:

- sessions and UI events
- trajectory events
- eval state snapshots
- subagent jobs and schedules
- curated memory
- telemetry events
- imports and FTS indexes

Commands:

```bash
vibe storage migrate
vibe storage status
vibe storage fts status
vibe storage fts rebuild
vibe storage fts optimize
vibe storage checkpoint
vibe storage vacuum
vibe storage search "sqlite migration" --cwd vibe
vibe storage import pi /path/to/pi-session-or-dir --batch-size 25
```

Eval APIs:

```elixir
Vibe.Paths.database()
Vibe.Storage.status()
Vibe.Storage.migrate!()
Vibe.Storage.FTS.status()
Vibe.Storage.FTS.rebuild()
Vibe.Storage.Search.query("sqlite migration", scopes: [:sessions, :memory], cwd: "vibe")
Vibe.Context.recall("sqlite migration", cwd: "vibe", limit: 3)
```

Use `VIBE_HOME` or `VIBE_DB_PATH` to isolate a dev/test instance.
