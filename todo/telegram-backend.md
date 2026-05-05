# Telegram Backend TODO

## Library choice

Prefer `ex_gram` unless implementation research finds a blocker.

- `ex_gram` is the best fit for Exy:
  - Bot API 9.6 support as of v0.65.0.
  - Polling and webhook update delivery.
  - Req adapter.
  - Typed generated methods/models.
  - Middleware, multiple bots, telemetry/OpenTelemetry support.
  - MessageEntity builder and optional MDEx integration for Markdown-safe Telegram output.
- `telegram_bot_api` is a recent Erlang alternative with Bot API 9.5 support, but has much lower adoption and is lower-level.
- `nadia` is historically popular but stale for modern Bot API features.
- Telegram Bot API itself does not provide token-level AI response streaming. Streaming UX is implemented by sending a placeholder message and periodically editing it as Exy emits stream/tool-progress events.

## Architecture

- Add a supervised backend under `Exy.Gateway.Telegram` or `Exy.Backends.Telegram`.
- Keep Telegram as an adapter over Exy semantic session APIs:
  - inbound Telegram updates -> `Exy.Session` commands
  - Exy UI/session events -> Telegram send/edit/delete operations
- Do not let agent APIs know about Telegram, Bot API, polling, webhooks, or edit throttling.
- Support both delivery modes:
  - polling for local/dev
  - webhook for production/Phoenix endpoint
- Store gateway state durably where needed:
  - telegram chat id -> Exy session id
  - message id for active streamed response
  - user allowlist / group allowlist
  - per-chat current model/effort if exposed

## Streaming UX

- On user prompt:
  - create or attach an Exy session for the Telegram chat
  - send a placeholder message such as `Thinking…`
  - subscribe to semantic Exy UI/session stream events
  - edit the placeholder message with throttled accumulated assistant text
  - finalize with final Markdown-safe text and inline keyboard
- Throttle edits to avoid Telegram rate limits:
  - min interval around 750-1500ms
  - edit only when content changed materially
  - coalesce rapid token deltas
  - gracefully handle `message is not modified`
- Split long responses across Telegram message limits.
- Surface tool progress compactly without leaking raw tool output by default.

## Attachments

- Text messages -> prompt text.
- Photos/images/documents -> Exy semantic content attachments or artifact files.
- Voice notes -> optional transcription pipeline before prompt submission.
- Generated files/artifacts -> send as documents/photos where appropriate.

## Controls

- Commands:
  - `/start`, `/help`
  - `/new` start a fresh Exy session
  - `/model`, `/effort` if exposing model controls is desired
  - `/cancel` cancel active run
  - `/sessions` or `/attach` only if it remains manageable in chat UX
- Inline keyboard on final answer:
  - Regenerate
  - Continue
  - Copy/plain text if useful
  - maybe Open Web UI/session link when Exy web server is enabled

## Security

- Required token from Exy auth/config, never committed.
- Allowlist users/chats by Telegram user id/chat id.
- Group mode must respect BotFather privacy mode behavior.
- Webhook endpoint should use secret token/path and validate Telegram headers when available.
- Avoid raw prompt/tool/secret telemetry.

## Validation

- Unit tests for update normalization, allowlist, session mapping, throttled edit coalescing, markdown/entity rendering, callback parsing.
- Adapter tests should use ExGram test adapter/mocks and avoid live Telegram calls.
- Optional live smoke behind an env guard:
  - send message
  - stream/edit response
  - image attachment
  - cancel/regenerate callback
