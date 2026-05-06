# Web UI TODO

## Implemented baseline

- Phoenix/Hex-inspired app shell with orange/violet accents and compact metadata cards.
- Volt-backed asset build for `assets/web/app.css` and `assets/web/app.ts` into `priv/static/assets/app.css` and `app.js`.
- Sessions dashboard with runtime snapshot, filtering, stats, and session cards.
- Session workbench with semantic `Vibe.UI.State` rendering, live transcript, composer, session metadata, and runtime inspector.
- Storage-backed search page using `Vibe.Storage.Search`.
- Runtime page with BEAM runtime info, top processes, ETS tables, and active session count.

## Next phases

- Rich tool-call cards matching TUI semantics for eval/read/write/edit/ast/lsp/command output.
- Clickable inspector for selected messages, tool calls, raw UI events, timing, metadata, and errors.
- Web search/fetch playground using `Web.search/2`, `Web.fetch/2`, selector preview, rendered Markdown, raw HTML/JSON tabs, and send-to-session actions.
- Memory page for scoped memory search, edit, promote-from-session, and source inspection.
- Subagent/job monitor with parent-child session tree, attach/open controls, output tails, cancellation, and schedule status.
- Docs/help page backed by `Vibe.Docs` topics.
- Model/profile/settings page for active agent profile, provider credential status, and theme.
- Trace/replay view for TUI/state/debug artifacts and assistant stream ordering diagnostics.
- Keyboard shortcuts and command palette hooks in `assets/web/hooks`.
- Responsive mobile/tablet drawers for sidebar and inspector.
