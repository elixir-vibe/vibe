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

For visual TUI artifacts, record the actual terminal byte stream with a native gzip-compressed cast:

```bash
VIBE_TUI_CAST=/tmp/vibe-session.vibe-tui.etf.gz mix vibe
```

The recording contains conversation output and terminal control bytes. Input bytes are redacted by default; set `VIBE_TUI_CAST_INPUT=1` only in disposable sessions if raw input is needed. Inspect recordings from eval or `mix run`:

```elixir
Vibe.TUI.Cast.info("/tmp/vibe-session.vibe-tui.etf.gz")
Vibe.TUI.Cast.snapshot!("/tmp/vibe-session.vibe-tui.etf.gz", time_ms: 1_000)
Vibe.TUI.Cast.export_asciinema("/tmp/vibe-session.vibe-tui.etf.gz", "/tmp/vibe-session.cast")
```
