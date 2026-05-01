# Troubleshooting

## Isolate a dev instance

```bash
EXY_HOME=/tmp/exy-dev exy
```

Useful paths:

```text
~/.exy/exy.db
~/.exy/auth.json
~/.exy/server.cookie
~/.exy/server.out
~/.exy/sessions/<id>.log
~/.exy/skills
```

## Auth

```bash
exy --login codex
```

In eval:

```elixir
Exy.Auth.ensure_fresh("openai-codex")
Exy.Auth.usage("openai-codex")
```

## Server/session state

```bash
exy server status
exy server restart
exy sessions --live
```

## Storage

```bash
exy storage status
exy storage migrate
exy storage fts status
```

In eval:

```elixir
Exy.Storage.status()
Exy.Telemetry.summary()
Exy.Session.list()
```

## Debug traces

Trace capture is opt-in and intended for development/debugging. Avoid recording raw prompts, file contents, tool outputs, secrets, or OAuth tokens in telemetry metadata.

For stream-ordering investigations, use `EXY_STREAM_TRACE_DIR` only in disposable/debug sessions.
