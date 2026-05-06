# Troubleshooting

## Isolate a dev instance

```bash
VIBE_HOME=/tmp/vibe-dev vibe
```

Useful paths:

```text
~/.vibe/vibe.db
~/.vibe/auth.json
~/.vibe/server.cookie
~/.vibe/server.out
~/.vibe/sessions/<id>.log
~/.vibe/skills
```

## Auth

```bash
vibe --login codex
```

In eval:

```elixir
Vibe.Auth.ensure_fresh("openai-codex")
Vibe.Auth.usage("openai-codex")
```

## Server/session state

```bash
vibe server status
vibe server restart
vibe sessions --live
```

## Storage

```bash
vibe storage status
vibe storage migrate
vibe storage fts status
```

In eval:

```elixir
Vibe.Storage.status()
Vibe.Telemetry.summary()
Vibe.Session.list()
```

## Debug traces

Trace capture is opt-in and intended for development/debugging. Avoid recording raw prompts, file contents, tool outputs, secrets, or OAuth tokens in telemetry metadata.

For stream-ordering investigations, use `VIBE_STREAM_TRACE_DIR` only in disposable/debug sessions.
