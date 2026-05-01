# Storage

Exy stores durable local state in SQLite through Ecto. The default database path is:

```text
~/.exy/exy.db
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
exy storage migrate
exy storage status
exy storage fts status
exy storage fts rebuild
exy storage fts optimize
exy storage checkpoint
exy storage vacuum
exy storage search "sqlite migration" --cwd exy
exy storage import pi /path/to/pi-session-or-dir --batch-size 25
```

Eval APIs:

```elixir
Exy.Paths.database()
Exy.Storage.status()
Exy.Storage.migrate!()
Exy.Storage.FTS.status()
Exy.Storage.FTS.rebuild()
Exy.Storage.Search.query("sqlite migration", scopes: [:sessions, :memory], cwd: "exy")
Exy.Context.recall("sqlite migration", cwd: "exy", limit: 3)
```

Use `EXY_HOME` or `EXY_DB_PATH` to isolate a dev/test instance.
