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
- `TELEGRAM_POLL_TIMEOUT_S` — long-poll timeout, default `5` to keep diagnostics responsive.
- `TELEGRAM_POLL_RECEIVE_TIMEOUT_MS` — HTTP receive timeout for long-poll requests, default `10000`.

Telegram responses are rendered as safe Telegram HTML. Exy escapes raw HTML, maps a small Markdown-like subset (`**bold**`, `*italic*`, inline code, fenced code) to Telegram tags, splits long final sends below Telegram's 4096-character limit, treats `message is not modified` edits as success, and falls back to plain text when HTML delivery is rejected.

The polling transport clears stale webhooks before long polling so a bot can be moved between webhook and polling mode safely.

## Telegram topics

Exy preserves Telegram `message_thread_id` as `Exy.Gateway.Source.thread_id` for both forum-enabled groups and private chats with bot topics enabled. This matches Telegram Bot API 9.4+ private-chat topics and keeps independent Exy sessions per visible bot topic:

```text
gateway:telegram:dm:<chat-id>:<message-thread-id>
gateway:telegram:group:<chat-id>:<message-thread-id>[:<user-id>]
```

For forum groups, Telegram omits `message_thread_id` for the General topic. Exy represents that internal source thread as `"1"`, but outbound adapters omit `message_thread_id: 1` because Telegram expects General-topic sends without the wire thread id.

Hermes currently supports Telegram topics in the same broad shape: it preserves `message.message_thread_id`, maps forum General to thread id `"1"`, sends/edit/photos/actions with `message_thread_id`, and has configured DM topic setup/mapping plus configured group topic metadata. Hermes topic-profile routing is still under active work in upstream PRs/issues, so Exy should treat per-topic profile/skill routing as a follow-up rather than relying on it as a settled upstream contract.
