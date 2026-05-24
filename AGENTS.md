# Vibe Agent Guidelines

This repository is part of the Elixir Vibe organization.

## Core architecture

- Keep model-facing tool count minimal. Prefer Vibe helper modules callable from `Vibe.Eval` over narrow external tools.
- User-facing interactions should flow through UI-neutral session commands, typed semantic events, reducers, and renderer-neutral presentation values. Keep execution ownership in lifecycle modules such as `Vibe.Session.*Lifecycle`; keep context serialization in dedicated context helpers; keep TUI/Web limited to input adaptation and rendering.
- Auth, plugins, runtimes, slash commands, providers, storage imports, and similar extension points should be behaviour/protocol based so future implementations can be added without changing callers.
- Avoid static catalogs/registries when modules can be discovered idiomatically from compiled application modules or dependency availability.
- Design APIs for agents to use comfortably: return structured, compact, actionable maps with summaries and failure details in one call.
- Keep durable runtime state in local SQLite through Ecto schemas, migrations, and `Vibe.Repo`; do not add app-level raw SQL storage helpers. Use `Vibe.Storage.migrate!/0`, `Vibe.Storage.status/0`, and storage/search modules for lifecycle and introspection. Keep SQLite FTS DDL/query fragments isolated under storage FTS modules.
- Domain structs that cross JSON/storage/transport boundaries should use explicit boundary protocols or typed representation modules. Keep primitive JSON helpers primitive/container-only; avoid broad centralized encoders, arbitrary semantic `Jason.Encoder` impls, or static event-type codec maps when typed decoders can do the job.

## Eval, commands, and context

- Prefer eval aliases: `Cmd` (`Vibe.Command`) for supervised shell commands, `MD` (`Vibe.MD`) for Markdown output, and `Web` (`Vibe.Plugins.WebSearch`) for web access. Use `System.cmd/3` only for tiny bounded commands.
- Session eval state belongs in `Vibe.Eval`; per-agent scratch state belongs in `Vibe.Agent.Memory`; curated long-term facts belong in `Vibe.Memory` / `Vibe.Memory.Manager`.
- Model/role preferences live in editable TOML via `Vibe.Agent.Profile`. Model and effort switching are session-level semantic commands/keybindings first; slash commands should be thin aliases. Internal effort values follow Pi-style atoms: `:off`, `:minimal`, `:low`, `:medium`, `:high`, `:xhigh`; parse strings only at UI/config boundaries.
- `mix vibe` is the default interactive TUI entrypoint; preserve non-interactive paths through flags like `--print`, `--eval`, `--checks`, and `--sessions`.
- `vibe sessions` should be human-friendly by default: recent useful sessions only. Put exhaustive listings behind `--all` and destructive cleanup behind explicit subcommands.

## Web, plugins, and presentation

- Web access should go through `Web` and provider behaviours. Put network/provider concerns in request opts (`provider`, `timeout`, `headers`, search filters); put local result transformations in pipeable helpers (`Web.select!/2`, `Web.truncate/2`, `Web.filter_domain/2`, `Web.take/2`).
- Parse HTML with `Web.parse_html!/1` and Floki; never use regular expressions or ad-hoc string stripping for HTML.
- Markdown rendering belongs to `Vibe.Markdown` implementations and should be invoked with `MD.doc/1` or `MD.to_markdown/1`; do not add renderer-specific markdown/text helpers to unrelated modules.
- Plugins may run supervised background children, update semantic UI state through `Vibe.Plugin.UI`, register slash command modules through `Vibe.Plugin.commands/1`, and expose renderer-neutral output through `Vibe.Markdown` or `Vibe.Presentation.*` values.
- Core web UI should expose generic plugin surfaces only. Plugins own specific forms, labels, actions, and result semantics; core owns discovery, status, lifecycle, and generic rendering.
- Plugin-owned UI should use renderer-neutral presentation (`Vibe.Presentation.Document` / `Section` / `Widget`) and `Vibe.Plugin.UI`; avoid plugin-specific HEEx/HTML/Tailwind/ANSI contracts in core.

## Terminal/TUI

- Terminal rendering primitives live under `Vibe.Terminal.*`. TUI rendering should stay semantic and iodata-first; avoid raw markdown markers/fences and renderer-owned canonical semantics.
- Put detailed TUI behavior and reusable rendering guidance in the relevant module docs (`Vibe.TUI.*`, `Vibe.Terminal.*`, widgets, renderers) so both agents and users see it at the API boundary.
- Use shared TUI layout/widget helpers instead of ad-hoc width math. Preserve chat vertical rhythm: blank space between message blocks and between history and footer/status, no gap between footer and prompt.
- Loader/working indicators should be driven by BEAM events/timers and repaint immediately without waiting for keyboard input.
- Use MDEx streaming documents for partial LLM Markdown and Lumis terminal highlighting for fenced code blocks instead of hand-rolled parsers/highlighters.
- Storybook output is a visual regression surface; inspect it after changing TUI/Markdown rendering.
- Prefer `IO.ANSI` or established terminal libraries over raw ANSI escape strings. If raw terminal control is unavoidable, isolate it behind a small named adapter and document why.
- Use Ghostty.TTY for interactive current-terminal runtime and Ghostty.KeyDecoder/Ghostty.KeyEvent for input. Do not add Vibe-local `stty`, `/dev/tty`, raw terminal-mode adapters, or hard-coded VT byte fixtures when Ghostty.Test can express the behavior.

## Development workflow

- Use `Vibe.Code.AST`/ExAST for Elixir syntax search, replace, and diff. Do not use grep for code structure.
- Use OTP supervision for background work and subagents.
- Keep prompts in `priv/prompts/*.md` and embed them at compile time through `Vibe.Prompts` with `@external_resource`.
- Keep non-immediate follow-up work in focused `todo/*.md` files instead of scattered TODO comments or general notes.
- For Mix task help, use Mix's built-in help rendering (`@moduledoc` + `Mix.Tasks.Help`) instead of hand-rolled CLI help formatters.
- Use `OptionParser` or Mix/Elixir built-ins for argv parsing and switch detection; avoid ad-hoc manual flag scans.
- Prefer idiomatic OTP/Elixir APIs over ad-hoc path/process handling, e.g. `Application.app_dir/2` for priv files and Erlang purge/delete/load APIs for hot reload.
- For Livebook-style execution and `Mix.install/2`, isolate work in a child BEAM/runtime; do not pollute Vibe's long-running VM.

## Self-improvement and testing

- Self-improvement should prefer skills and helper modules before changing runtime core. Review executable skill code before sharing or installing it.
- Before self-modification, add/update tests for intended behavior, run `Vibe.SelfPatch.preflight/1`, then patch.
- Validate self-patches through `Vibe.Code.Checks.analyze/1`; use the returned `report.failures` instead of rerunning checks with different inspect/options. Prefer Elixir APIs over shelling out to Mix tasks.
- Keep default tests fast without weakening coverage: prefer deterministic process handshakes, monitor/receive synchronization, and `refute_received` after synchronous calls over fixed sleeps or long `refute_receive` delays.
- Never use uncapped `receive` loops as timeout-test fixtures.
- Put expensive real-environment tests behind `@tag :integration`; default tests should use deterministic fakes or semantic renderers.
- When optimizing tests, run the full default suite with a hard external timeout and avoid changes that only reduce ExUnit-reported time while worsening wall-clock time or reducing meaningful coverage.

## Safety and observability

- Store runtime observability under `Vibe.Telemetry` backed by SQLite. Agents should introspect local telemetry through `Vibe.Telemetry.recent/1`, `Vibe.Telemetry.all/1`, and `Vibe.Telemetry.summary/1` instead of scraping logs.
- Avoid recording raw prompts, file contents, tool outputs, secrets, or OAuth tokens in telemetry metadata; prefer IDs, counts, durations, statuses, and byte/token sizes.
- Subagents are supervised jobs with child sessions. Use `Vibe.Subagents.start/2`, `ask/2`, `run_many/2`, and `schedule/2`; persist job/schedule state through `Vibe.Subagents.JobStore` / `Vibe.Subagents.Store`, not JSONL files. Subagents should report findings to the parent instead of writing global memory directly.
- Storage imports should add a `Vibe.Storage.Importer` implementation, preserve source metadata such as cwd, and distinguish conversation text from imported tool output for search quality.
