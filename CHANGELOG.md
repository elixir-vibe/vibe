# Changelog

## v0.2.0 - Unreleased

### Highlights

- Renamed the project from Exy to Vibe and moved it under the Elixir Vibe organization.
- Added the default `mix vibe` interactive TUI and preserved non-interactive CLI flows for print, eval, checks, sessions, and server commands.
- Added a LiveView web interface for sessions, search, memory, plugins, skills, runtime state, jobs, gateways, settings, and storage.
- Added a singleton background server model so multiple `mix vibe` clients can attach to shared server-owned sessions without rebinding the web endpoint.
- Added persisted session goals with `/goal`, goal status controls, hidden goal context injection, TUI/web goal visibility, eval helpers, and guarded idle continuation.

### TUI and rendering

- Reworked the TUI around semantic UI state, view models, render trees, partial rendering, and renderer-neutral blocks.
- Added multiline editor support, autocomplete, selector overlays, confirmation overlays, slash-command pickers, notification blocks, and footer status indicators.
- Added native terminal scrollback preservation, TerminalPainter diffing, resize handling, OSC 133 zones, OSC 8 hyperlinks, window-title updates, and TUI cast recording.
- Added semantic tool display documents and dedicated TUI renderers for eval, command, file read/edit, image, web, and patch output.
- Added Markdown rendering improvements including MDEx streaming, Lumis syntax highlighting, table wrapping, Mermaid rendering through Boxart, and safer iodata-first ANSI handling.
- Added storybook snapshots and trace/audit tooling for TUI rendering regressions.

### Web UI

- Added Phoenix/LiveView web pages for sessions, runtime, search, memory, jobs, plugins, skills, storage, gateways, and settings.
- Added web authentication, persisted endpoint secrets, session transcript streaming, semantic web message rendering, structured tool widgets, image previews, artifact routes, and live session list updates.
- Normalized page layouts and shared web UI primitives across sessions, runtime, gateways, plugins, storage, and skills.
- Added PhoenixIconify icons and improved code/source panels while reducing decorative icon usage.

### Sessions, storage, and memory

- Moved durable runtime state to SQLite/Ecto schemas and migrations for sessions, UI events, trajectory events, eval state, telemetry, memory, subagent jobs, schedules, imports, and goals.
- Added persisted UI event replay, session branching, useful session listings, empty-session pruning, and searchable imported transcripts.
- Added SQLite FTS search and recall context integration.
- Added scoped memory layers for session eval state, per-agent scratch memory, curated user/global/workspace memory, and memory management APIs.
- Added local telemetry storage, summaries, system alarm recording, and runtime alert surfacing.

### Agent runtime and tools

- Added stateful `Vibe.Eval` with persisted bindings/env snapshots, eval aliases (`Cmd`, `MD`, `Web`, `Goal`, plugin/skill APIs), cancellation, and higher command timeout ceilings.
- Added supervised command execution with streaming output, full-output logs, and reusable Pi-style tool-output windowing with full-output recovery pointers.
- Added file read/write/edit tools, AST diff rendering, image prompt attachments, image resizing backends, artifact storage, and direct clipboard-image paste in the TUI composer.
- Added provider-neutral web fetch/search tools with pipeable helpers for selecting, truncating, filtering, and parsing HTML.
- Added token-based context compaction and conversation recall.

### Plugins, skills, and subagents

- Added behaviour-based plugin lifecycle hooks, plugin-owned semantic UI widgets/documents, plugin status updates, and plugin command registration.
- Added built-in rules, safety, notify, question, and WebSearch plugin capabilities.
- Added executable Elixir skills through `Vibe.Skill.Script` and generated skill support.
- Added supervised subagents with child sessions, job storage, schedules, locking, lifecycle UI blocks, and CLI attachment flows.

### Gateways and remote access

- Added generic gateway message/source/media contracts and Telegram gateway support with polling, normalization, topic-aware session keys, diagnostics, status UI, formatting, and gateway actions.
- Added gateway session bridging so external chat messages can start/attach sessions and receive streamed or final assistant responses.
- Added remote server/session access through Erlang distribution and a constrained SSH transport, plus known-node and connect commands.
- Added TLS certificate generation and TLS distribution support for trusted BEAM remotes.

### Models and providers

- Added editable model/provider profiles, model and effort switching, model selector UI, fuzzy model resolution, and OpenRouter passthrough handling.
- Added OpenCode/Codex auth provider integration and provider-driven auth flows.
- Added semantic prompt content/image propagation into agent requests.

### Quality, performance, and dependencies

- Added and expanded CI/static analysis coverage with compile warnings, format checks, Credo, Dialyzer, ExDNA, Reach smell checks, and project self-check helpers.
- Stabilized async, streaming, gateway, eval, TUI, and standalone-runtime tests; optimized fixed waits and long-running fixtures.
- Improved TUI repaint performance and avoided render starvation under load.
- Bumped and adopted new dependency features across Req, Finch, Volt, Vize, QuickBEAM, Reach, ex_ast, Ghostty, and PhoenixIconify.
- Added `glob_ex` for Volt 0.12 glob invalidation support.

## v0.1.0

- Initial Hex release of the BEAM-native coding agent substrate.
- Added the early CLI, agent runtime, local session flow, eval/check helpers, prompt handling, and packaging/install documentation.
