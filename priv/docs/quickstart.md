# Quickstart

Start Vibe from a checkout or installed escript:

```bash
mix vibe
vibe
```

Sign in with ChatGPT/Codex OAuth when needed:

```bash
vibe --login codex
```

Start a fresh server-owned session:

```bash
vibe new
vibe n
```

List and attach sessions:

```bash
vibe sessions
vibe ls
vibe attach <session-id>
vibe a <session-id>
```

Send work to a session without opening the TUI:

```bash
vibe send <session-id> "Run tests and summarize failures"
```

Run a non-interactive prompt and print the answer:

```bash
vibe -p "Inspect this project and suggest next steps"
```

Start background work and attach later:

```bash
vibe --bg "Research this failure and summarize likely fixes"
vibe sessions
vibe a <session-id>
```

Use direct model calls for simple one-shot prompts without the agent runtime:

```bash
vibe --direct "Summarize @README.md"
```

Open the prototype web UI over the same session/runtime model:

```bash
vibe --web --port 4321
```

Run the Telegram gateway in foreground polling mode:

```bash
TELEGRAM_BOT_TOKEN=123:abc \
TELEGRAM_ALLOWED_USERS=123456 \
vibe gateway telegram --foreground --bot-username vibe_bot
```

Group chats should normally require a mention or reply:

```bash
TELEGRAM_BOT_TOKEN=123:abc \
TELEGRAM_GROUP_ALLOWED_CHATS=-100123456 \
vibe gateway telegram --foreground --bot-username vibe_bot --require-mention
```

Run local validation gates:

```bash
mix ci
```

Use built-in help for task-focused docs:

```bash
vibe help eval
vibe help sessions
vibe help subagents
```
