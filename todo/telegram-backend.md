# Telegram Backend TODO

## Hermes source findings

Inspected `NousResearch/hermes-agent` directly under `/tmp/hermes-agent`.

Key source files:

- `gateway/platforms/base.py`
- `gateway/platforms/telegram.py`
- `gateway/stream_consumer.py`
- `gateway/run.py`
- `gateway/session.py`
- `gateway/config.py`
- `gateway/platforms/ADDING_A_PLATFORM.md`
- tests under `tests/gateway/test_telegram_*.py` and `tests/gateway/test_stream_consumer.py`

Hermes uses `python-telegram-bot[webhooks]>=22.6,<23`, not a custom Telegram wire implementation.

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
- Telegram Bot API itself does not provide token-level AI response streaming. Hermes-style streaming is implemented by sending a first message and periodically editing it while agent/model deltas arrive.

## Hermes architecture to port conceptually

Hermes has a platform adapter interface:

- inbound platform update -> normalized `MessageEvent`
- `MessageEvent.source` -> deterministic session key
- gateway/session runner owns agent work
- outbound text/media/tool progress -> adapter `send`, `edit_message`, `delete_message`, media senders

Exy equivalent should be:

- `Exy.Gateway.Telegram.Update` or `Exy.Gateway.Update` for normalized inbound messages.
- `Exy.Gateway.Source` for platform/chat/user/thread identity.
- `Exy.Gateway.Telegram.Adapter` for Bot API calls.
- `Exy.Gateway.Telegram.StreamConsumer` or generic `Exy.Gateway.StreamConsumer` for stream-to-edit rendering.
- Telegram talks to `Exy.Session` semantic commands/events; agent APIs do not know Telegram exists.

Recommended namespace:

```elixir
Exy.Gateway.Telegram
Exy.Gateway.Telegram.Supervisor
Exy.Gateway.Telegram.Config
Exy.Gateway.Telegram.Bot
Exy.Gateway.Telegram.Update
Exy.Gateway.Telegram.Source
Exy.Gateway.Telegram.SessionKey
Exy.Gateway.Telegram.StreamConsumer
Exy.Gateway.Telegram.Markdown
Exy.Gateway.Telegram.Attachments
Exy.Gateway.Telegram.Callbacks
```

Consider making `Source`, `MessageEvent`, `StreamConsumer`, and session key generation generic if other chat backends are likely.

## Delivery modes

Hermes supports both:

- polling by default
- webhook when `TELEGRAM_WEBHOOK_URL` is configured

Exy should support:

- polling for local/dev
- Phoenix webhook endpoint for production/server mode

Webhook security is mandatory. Hermes refuses to start webhook mode without `TELEGRAM_WEBHOOK_SECRET`; Exy should similarly require a secret token/path and validate Telegram's secret-token header.

Hermes also clears stale webhooks before polling. Exy should do the same to avoid polling silently receiving no updates.

## Connection/reliability lessons from Hermes

Hermes contains significant hardening we should not ignore:

- platform lock by bot token to avoid two gateway processes polling the same bot.
- explicit HTTP pool/connect/read/write timeouts.
- proxy support.
- fallback IP transport for Telegram reachability issues.
- polling conflict detection and limited retries before fatal error.
- network reconnect with getUpdates probe after restart.
- clean disconnect cancels pending album/text batching tasks and stops polling/webhook.

For Exy first implementation, do the safe subset:

- single supervised bot process per token.
- explicit polling conflict error.
- clear stale webhook before polling.
- reasonable Req/ExGram timeout config.
- proper child shutdown and task cancellation.

Defer fallback IP transport unless it becomes necessary.

## Normalized inbound event shape

Hermes `MessageEvent` fields worth mirroring:

- `text`
- `message_type`: text, command, photo, video, audio, voice, document, sticker, location
- `source`: platform, chat_id, chat_type, user_id, user_name, thread_id, chat_topic
- `message_id`
- `platform_update_id`
- `media_urls` / `media_types` as cached local files
- reply context: `reply_to_message_id`, `reply_to_text`
- optional auto skill / channel prompt
- timestamp

Exy should probably define structs:

```elixir
%Exy.Gateway.Source{}
%Exy.Gateway.Message{}
```

and Telegram-specific decoding under `Exy.Gateway.Telegram.Update`.

## Session key behavior

Hermes session keys:

- DMs: include platform + dm chat id, plus thread id if present.
- Groups/channels: include platform + chat type + chat id + optional thread id.
- Group sessions default to per-user isolation unless configured otherwise.
- Threaded sessions default to shared by all participants unless `thread_sessions_per_user` is enabled.

Exy should explicitly choose and test:

- DM: one Exy session per Telegram DM chat.
- Group without topic: probably one session per group or per user depending config.
- Group/forum topic: default one session per topic shared by participants.
- Include Telegram `message_thread_id`; map General topic (`1`) carefully.

## Group gating and authorization

Hermes separates two concerns:

1. trigger gate in Telegram adapter:
   - DMs unrestricted after auth.
   - group messages can require explicit mention/reply/wake regex.
   - free-response chats bypass mention requirement.
   - ignored thread ids are dropped.
2. user/chat authorization in gateway runner:
   - `TELEGRAM_ALLOWED_USERS`
   - `TELEGRAM_GROUP_ALLOWED_USERS`
   - `TELEGRAM_GROUP_ALLOWED_CHATS`
   - `TELEGRAM_ALLOW_ALL_USERS`
   - global allowlist / allow-all

Exy should implement both layers:

- mention/reply/wake-word gate to reduce accidental group activations.
- allowlist enforcement before creating/submitting Exy sessions.
- callback authorization for inline buttons, not just incoming messages.

Use BotFather privacy-mode docs in setup help; privacy mode changes what group messages the bot receives at all.

## Streaming consumer behavior to port

Hermes `GatewayStreamConsumer` is generic across platforms and should inspire Exy's implementation.

Important details:

- Agent callback is sync/thread-safe; consumer drains into async loop. In Exy this becomes BEAM message/event ingestion.
- Config:
  - `edit_interval`: default 1.0s
  - `buffer_threshold`: default 40 chars
  - `cursor`: ` ▉`
  - `buffer_only`
  - `fresh_final_after_seconds`: default 60s; applied to Telegram
- Accumulates deltas and periodically sends/edits one message.
- Appends cursor for non-final edits.
- Suppresses raw think/reasoning tags in streamed text.
- Handles segment breaks/tool boundaries by finalizing current text and starting a fresh message so tool progress remains chronological.
- Handles commentary messages separately and does not mark them as final answer delivery.
- Splits long messages using platform limit; Telegram limit is 4096 UTF-16 code units, not codepoints.
- Skips cursor-only updates and short first messages with cursor to avoid stuck visible cursor.
- Tracks last sent text and skips identical edits.
- Treats `message is not modified` as success.
- Handles flood control by adaptive backoff and eventually disables progressive edits for the run.
- On edit failure, final fallback sends only the missing continuation, not the whole response.
- On long-running Telegram streams, sends a fresh final message and best-effort deletes stale preview so visible timestamp reflects completion.

Exy should build a generic BEAM-native stream consumer with similar rules before Telegram-specific polish.

## Telegram formatting lessons

Hermes uses MarkdownV2 but has a lot of custom escaping and fallbacks:

- Converts standard Markdown to Telegram MarkdownV2.
- Escapes special chars outside code spans/fences.
- Protects code blocks and inline code.
- Converts headers to bold.
- Rewrites GFM tables to Telegram-friendly row groups because Telegram has no table syntax.
- Falls back to plain text when Telegram rejects Markdown parsing.
- Uses UTF-16 length helpers for Telegram limits.

For Exy, prefer `ExGram` MessageEntity builder / MDEx integration if reliable, but still test:

- code fences
- inline code
- links with parentheses
- tables
- long Unicode/emoji responses
- fallback to plain text on parse failure

## Attachments and media

Hermes caches Telegram media locally before handing to the agent:

- photos -> local image cache, largest photo size
- media groups/albums -> debounced and merged into one event
- photo bursts without `media_group_id` -> debounced and merged
- voice/audio -> local audio cache for transcription
- video -> local video cache
- documents -> local document cache with supported extension allowlist
- text files (`.txt`, `.md`) under 100KB are injected into prompt text
- unsupported document types produce a user-visible message
- documents over 20MB are rejected
- stickers:
  - static sticker downloaded and analyzed with vision, cached by `file_unique_id`
  - animated/video stickers become textual placeholders

Exy first pass:

- photos/images -> session artifact file + semantic image content
- documents -> session artifact file; text files may be inserted as file content block
- voice -> defer unless transcription pipeline exists
- media group debounce -> include from day one if supporting images, otherwise albums interrupt active sessions

## Outbound media

Hermes platform base supports native media senders and Telegram specializes:

- `send_image`, `send_multiple_images` via media group chunks up to 10
- `send_document`
- `send_voice` / `send_audio` with Telegram format constraints:
  - `sendVoice`: `.ogg` / `.opus` only when voice-like
  - `sendAudio`: `.mp3` / `.m4a`
  - other audio falls back to document
- `send_video`, `send_animation`

Exy should initially support sending artifact images/documents back to Telegram and leave generated audio/video as follow-up.

## Commands and controls

Hermes registers Telegram bot commands from a central command registry and supports interactive callbacks for:

- update prompts
- exec approval buttons
- slash-command confirmation buttons
- model picker provider/model selection

Exy Telegram controls should start smaller:

- `/start`, `/help`
- `/new`
- `/cancel`
- `/model` and `/effort` only if the chat UX is manageable
- inline final answer buttons:
  - Regenerate
  - Continue
  - maybe Open Web Session

Callbacks must re-check authorization and include compact callback data. Telegram callback data limit is 64 bytes.

## Reactions / processing lifecycle

Hermes can set Telegram reactions when processing starts/completes:

- 👀 on start
- 👍 or 👎 on completion/failure

Exy can use this as optional polish after core streaming is stable.

## Implementation phases

### Phase 1: Generic gateway contracts

- Add `Exy.Gateway.Source` and `Exy.Gateway.Message` structs.
- Add deterministic session key module for platform/chat/user/thread.
- Add tests for DM, group, topic, per-user/per-thread isolation.

### Phase 2: Stream consumer

- Implement generic stream-to-edit consumer over adapter behaviour:
  - `send/4`
  - `edit/5`
  - `delete/3`
  - `send_typing/2`
- Port Hermes rules for interval, threshold, cursor, finalization, flood fallback, long-message split, no-op edit.
- Use Exy semantic UI/session events as input, not agent transport details.

### Phase 3: Telegram adapter with ExGram

- Add `ex_gram` dependency and Req adapter config.
- Polling connect/disconnect.
- Basic text/command update normalization.
- Authorization and group mention gating.
- Send/edit/delete text with Markdown fallback.

### Phase 4: Attachments

- Photo/image download to session artifact.
- Media group debounce.
- Document download with extension/size limits.
- Text document injection.

### Phase 5: Webhook mode

- Phoenix route with secret validation.
- Register/delete webhook commands or setup docs.
- Production config docs.

### Phase 6: Controls/polish

- Inline callbacks.
- Model/effort picker if needed.
- Processing reactions.
- Voice transcription.
- Outbound artifact/media delivery.

## Validation

Mirror Hermes test coverage themes:

- Telegram Markdown formatting and fallback.
- UTF-16 length splitting with emoji.
- Text batching for Telegram client-side split messages.
- Photo burst/media-group debouncing.
- Caption merge.
- Document allowlist/size/text injection.
- Group mention gate, mention entity boundaries, bot-command mentions.
- Group allowlists and chat allowlists.
- Topic/thread fallback and General topic behavior.
- Webhook secret required.
- Polling conflict detection.
- Network reconnect if implemented.
- Stream consumer cursor removal, final edit, fallback send, flood-control backoff, fresh-final behavior.
- Callback authorization.

## Open questions

- Should Exy implement a generic `Exy.Gateway` now, or keep Telegram-specific modules until a second backend appears?
- Should Exy use MarkdownV2 strings or Telegram MessageEntity lists as the primary formatting output?
- How much of Hermes' advanced reliability (fallback IPs, network reconnect probes, DM topics) belongs in Exy v1?
- Where should Telegram session mapping live: existing `Exy.Session.Store`, new gateway tables, or derived deterministic IDs only?
