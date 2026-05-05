# Gateways

Gateways connect external chat platforms to Exy semantic sessions. Platform code normalizes incoming updates into `Exy.Gateway.Message`, the generic runtime authorizes and dispatches them, and a session bridge streams assistant responses back through the platform adapter.

## Telegram polling

Set at least a bot token and one authorization rule:

```bash
TELEGRAM_BOT_TOKEN=123:abc \
TELEGRAM_ALLOWED_USERS=123456 \
exy gateway telegram --foreground --bot-username exy_bot
```

For groups, prefer explicit chat allowlists and mention/reply gating:

```bash
TELEGRAM_BOT_TOKEN=123:abc \
TELEGRAM_GROUP_ALLOWED_CHATS=-100123456 \
exy gateway telegram --foreground --bot-username exy_bot --require-mention
```

Useful environment variables:

- `TELEGRAM_BOT_TOKEN` — required unless `--token` is passed.
- `TELEGRAM_BOT_ID` / `TELEGRAM_BOT_USERNAME` — used for mention and reply detection.
- `TELEGRAM_ALLOWED_USERS` — comma-separated private/user allowlist.
- `TELEGRAM_GROUP_ALLOWED_USERS` — comma-separated user allowlist for groups.
- `TELEGRAM_GROUP_ALLOWED_CHATS` — comma-separated group chat allowlist.
- `TELEGRAM_ALLOW_ALL_USERS=true` — local testing only.
- `TELEGRAM_REQUIRE_MENTION=true` — require bot mention/reply/wake trigger in groups.
- `TELEGRAM_FREE_RESPONSE_CHATS` — group chats where every message is accepted after auth.
- `TELEGRAM_IGNORED_THREADS` — comma-separated forum topic ids to ignore.
- `TELEGRAM_STREAM_MODE=edit|draft|auto` — response streaming policy; edit mode is the stable fallback.

The polling transport clears stale webhooks before long polling so a bot can be moved between webhook and polling mode safely.
