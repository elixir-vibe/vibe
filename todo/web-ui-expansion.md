# Web UI Expansion Plan

## Principle

Expose Vibe by workflow, not as dashboard soup:

- Sessions: conversation work
- Tools: what happened in a session
- Jobs: background/subagent work
- Memory: what Vibe knows
- Settings: models/auth/plugins/skills/configuration
- Runtime: developer/operator health
- Storage: search, imports, FTS, database maintenance

Keep model/runtime implementation details available, but never let them dominate the primary user flow.

## Navigation

Top nav should stay small:

- Sessions
- Jobs
- Memory
- Runtime

Secondary/developer pages can live under Settings or contextual links:

- Models
- Auth
- Plugins
- Skills
- Storage
- Docs
- Trace
- Web Tools

## Session Workbench

Add session-level inspectors/tabs:

- Transcript
- Tools
- Context
- Events

First pass:

- Keep transcript as default.
- Add a tool timeline panel/section using semantic `Vibe.Presentation.Tool.from_tool/1`.
- Show tool name, status, summary, duration when available, and expandable structured output.
- Add context inspector later: system prompt, workspace instructions, skills, memory/recall summary.

## Sessions Index

Improve filters:

- All
- Live
- Recent
- Failed
- With tools
- With changes

Improve row metadata:

- live/idle/error
- model
- workspace
- last activity
- tool count
- token/cost
- file changes if available

Maintenance actions should stay secondary:

- Delete selected
- Prune empty
- Archive old
- Reindex selected

## Jobs/Subagents

Add `/jobs`.

Show:

- Running
- Queued
- Scheduled
- Completed
- Failed

Columns:

- job id
- parent session
- child session
- agent/profile
- status
- started/ended
- duration
- result summary

Actions:

- attach child session
- cancel
- retry
- view logs/events

## Memory

Add `/memory`.

Expose:

- global memories
- workspace memories
- session memories
- search
- source/session metadata

Actions:

- add manual memory
- edit
- delete
- promote/demote scope
- mark stale

## Plugins / Skills / Settings

Plugins page should show:

- loaded plugins
- supervised children
- slash commands
- model-facing actions
- eval aliases/APIs
- UI widgets
- status/errors

Skills page should show:

- installed skills
- workspace skills
- user skills
- executable skill scripts
- source path
- enabled/disabled
- validation errors

Settings should show:

- model profiles
- provider/auth status
- default model
- storage path
- web port
- debug/trace gates

## Runtime

Expand `/runtime` carefully:

- supervision tree
- session processes
- background commands/jobs
- high mailbox warnings
- crashed/restarting children
- tool duration/latency
- telemetry tables

## Storage/Search

`/search` is currently ambiguous. Convert to `/storage` or merge FTS results into Sessions.

Storage should expose:

- session search
- UI event search
- memory search
- FTS index status
- imports
- reindex actions

## Docs

Expose `priv/docs/*.md` as `/docs`.

Render docs with the same Markdown renderer.

## Near-term implementation order

1. Add session tool timeline/inspector.
2. Add `/jobs` page.
3. Add `/memory` page.
4. Convert `/search` into `/storage` or redirect it.
5. Add settings/models/auth/plugins/skills pages.
6. Add richer runtime views.
