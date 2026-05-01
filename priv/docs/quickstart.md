# Quickstart

Start Exy from a checkout or installed escript:

```bash
mix exy
exy
```

Sign in with ChatGPT/Codex OAuth when needed:

```bash
exy --login codex
```

Start a fresh server-owned session:

```bash
exy new
exy n
```

List and attach sessions:

```bash
exy sessions
exy ls
exy attach <session-id>
exy a <session-id>
```

Send work to a session without opening the TUI:

```bash
exy send <session-id> "Run tests and summarize failures"
```

Run a non-interactive prompt and print the answer:

```bash
exy -p "Inspect this project and suggest next steps"
```

Open the prototype web UI over the same session/runtime model:

```bash
exy --web --port 4321
```

Run local validation gates:

```bash
mix ci
```

Use built-in help for task-focused docs:

```bash
exy help eval
exy help sessions
exy help subagents
```
