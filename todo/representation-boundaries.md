# Representation Boundaries Refactor Plan

## Non-negotiables

- No compatibility aliases.
- No legacy fallback decoders for old shapes.
- No broad `to_map/1`, `from_map/1`, or `normalize/1` escape hatches for typed flows.
- No catch-all codec modules owning domain conversion.
- Use protocols at boundaries.
- Domain structs carry meaning only.
- UI consumes semantic events; it does not own the event model.
- Storage, presentation, web, and TUI are separate representation/surface boundaries.

## Core model

Vibe has these boundary families:

```text
Domain        Vibe.<Domain>.*
Event         Vibe.Event.*
UI            Vibe.UI.*
Presentation  Vibe.Presentation.* / Vibe.TUI.Presentation.* / Vibe.Web.Presentation.*
Storage       Vibe.Storage.*
Transport     Vibe.Remote.* / protocol-specific modules
```

Protocol-first rule:

```elixir
Vibe.Presentation.Presentable
Vibe.Storage.Persistable
Vibe.Storage.Restorable
```

Potential later transport protocols should only be introduced after storage and presentation boundaries are clean.

## Semantic events

`Vibe.UI.Event` is the wrong namespace if events are semantic session/runtime events consumed by TUI, Web, storage, plugins, sessions, and remote clients.

Target namespace:

```elixir
Vibe.Event
Vibe.Event.Bus
```

`Vibe.UI.*` should remain for interaction state, reducer, selectors, view models, notifications, and UI-only concepts.

Preferred event shape, initially:

```elixir
%Vibe.Event{
  id: binary(),
  session_id: binary(),
  at: DateTime.t(),
  payload: struct()
}
```

Payload modules use submodule hierarchy:

```elixir
Vibe.Event.Message.UserAdded
Vibe.Event.Message.AssistantAdded
Vibe.Event.Message.Cleared
Vibe.Event.Message.WorkingUpdated

Vibe.Event.AssistantStream.Started
Vibe.Event.AssistantStream.Delta
Vibe.Event.AssistantStream.ThinkingDelta
Vibe.Event.AssistantStream.Finished
Vibe.Event.AssistantStream.Aborted

Vibe.Event.Tool.Started
Vibe.Event.Tool.Updated
Vibe.Event.Tool.Finished

Vibe.Event.Goal.Set
Vibe.Event.Goal.Updated
Vibe.Event.Goal.Cleared
Vibe.Event.Goal.ContinuationStarted

Vibe.Event.RuntimeAlert.Set
Vibe.Event.RuntimeAlert.Cleared

Vibe.Event.Notification.Added
Vibe.Event.Notification.Expired

Vibe.Event.Session.Selected
Vibe.Event.Session.NewRequested
Vibe.Event.Session.Backgrounded
Vibe.Event.Session.ActiveUpdated

Vibe.Event.Model.Selected
Vibe.Event.Effort.Selected
Vibe.Event.Status.Changed
Vibe.Event.Title.Updated

Vibe.Event.Selector.Opened
Vibe.Event.Selector.Moved
Vibe.Event.Selector.Closed
Vibe.Event.Selector.Confirmed

Vibe.Event.Overlay.Opened
Vibe.Event.Overlay.Closed
Vibe.Event.Confirmation.Requested

Vibe.Event.Plugin.StatusUpdated
Vibe.Event.Plugin.StatusCleared
Vibe.Event.Plugin.WidgetUpdated
Vibe.Event.Plugin.WidgetCleared

Vibe.Event.ContextCompaction.Started
Vibe.Event.ContextCompaction.Finished
Vibe.Event.ContextCompaction.Failed

Vibe.Event.Subagent.Started
Vibe.Event.Subagent.Finished
```

Alternative later: fully typed event structs without wrapper metadata. Start with wrapper + typed payload unless implementation shows fully typed structs are simpler.

## UI layer

Keep UI-specific state and reducers under:

```elixir
Vibe.UI.State
Vibe.UI.Reducer
Vibe.UI.Message
Vibe.UI.Notification
Vibe.UI.Selector
Vibe.UI.ViewModel
Vibe.UI.Block
Vibe.UI.SlashCommands
```

`Vibe.UI.Reducer` is acceptable because it reduces semantic `Vibe.Event` values into UI state.

`Vibe.UI.Bus` should become `Vibe.Event.Bus` if it broadcasts semantic events.

## Presentation layer

Renderer-neutral presentation:

```elixir
Vibe.Presentation.Document
Vibe.Presentation.Section
Vibe.Presentation.Widget
Vibe.Presentation.Presentable
```

Surfaces:

```elixir
Vibe.TUI.Presentation.*
Vibe.Web.Presentation.*
```

Avoid domain-owned presentation modules long term:

```text
Avoid: Vibe.SystemAlarms.Presentation
Avoid: Vibe.Tool.Presentation if it is renderer-neutral presentation
```

Use protocol dispatch:

```elixir
Vibe.Presentation.Presentable.present(value)
```

Examples:

```text
Vibe.SystemAlarms.Alert -> Vibe.Presentation.RuntimeAlert or Document/Widget
Vibe.Tool.Event         -> Vibe.Presentation.Tool
Vibe.Goals.Goal         -> Vibe.Presentation.Goal or Widget
```

Web/TUI render presentation values, not domain values directly.

## Storage layer

Protocols:

```elixir
Vibe.Storage.Persistable
Vibe.Storage.Restorable
```

Storage representation structs:

```elixir
Vibe.Storage.Representation.Event
Vibe.Storage.Representation.Trajectory
Vibe.Storage.Representation.EvalSnapshot
Vibe.Storage.Representation.Goal
Vibe.Storage.Representation.ToolEvent
Vibe.Storage.Representation.Content.Text
Vibe.Storage.Representation.Content.Image
Vibe.Storage.Representation.ImageRef
Vibe.Storage.Representation.RuntimeAlert
Vibe.Storage.Representation.Usage
Vibe.Storage.Representation.Notification
Vibe.Storage.Representation.SubagentJob
Vibe.Storage.Representation.SubagentSchedule
```

DB row schemas remain separate:

```elixir
Vibe.Storage.Schema.*
```

Representation structs define current persisted shape and Jason encoding. Conversion is via protocol impls, not `from_domain/1`/`to_domain/1` helper sprawl.

Raw JSON maps may only be decoded at the storage boundary into current storage representation structs. No old-shape compatibility.

A module named `Codec` is usually a hidden representation boundary. If it encodes or decodes a domain value for storage, it belongs under `Vibe.Storage.Representation.*` plus storage protocols, not under `Vibe.Session.Store.Codec`. Reserve `Codec` only for true external wire formats with explicit protocol names, such as SSH protocol frames, LSP messages, or terminal cast blocks.

## Entity inventory

### Domain/session/event

```elixir
Vibe.Event
Vibe.Event.* payload structs
Vibe.Trajectory
Vibe.UI.State
Vibe.UI.Message
Vibe.UI.Notification
Vibe.UI.Selector
```

### Tool domain

```elixir
Vibe.Tool.Event
Vibe.Tool.Result
Vibe.Tool.AdapterResult
Vibe.Tool.Output
Vibe.Tool.Output.Window
Vibe.Tool.Builtin.*
```

Consider moving renderer-neutral `Vibe.Tool.Presentation` to `Vibe.Presentation.Tool` later.

### Model/content domain

```elixir
Vibe.Model.Content.Text
Vibe.Model.Content.Image
Vibe.Model.Usage
Vibe.Model.Error
Vibe.Model.Effort
Vibe.Model.Selection
```

### File/image domain

Current:

```elixir
Vibe.Files.ImageRef
Vibe.Files.ReadResult
Vibe.Image
```

Possible later singular namespace:

```elixir
Vibe.File.*
```

Do not rename this as part of the first representation slice unless necessary.

### Goal domain

```elixir
Vibe.Goals.Goal
```

### System/runtime domain

```elixir
Vibe.SystemAlarms.Alert
```

Domain alert must be semantic only: no title/message fields, no notification conversion, no storage helpers.

### Command/code/search/subagents

```elixir
Vibe.Command.Result
Vibe.Code.AST.Result
Vibe.Storage.Search.Result
Vibe.Subagents.JobInfo
Vibe.Subagents.Schedule
```

## Web search namespace

`lib/vibe/web_search` should not be a top-level parallel domain if web search is plugin-owned.

Target: move the whole search/fetch capability under the bundled plugin:

```elixir
Vibe.Plugins.WebSearch
Vibe.Plugins.WebSearch.SearchProvider
Vibe.Plugins.WebSearch.FetchProvider
Vibe.Plugins.WebSearch.Provider.Exa
Vibe.Plugins.WebSearch.Provider.ReqFetch
Vibe.Plugins.WebSearch.SearchResult
Vibe.Plugins.WebSearch.SearchItem
Vibe.Plugins.WebSearch.FetchResult
Vibe.Plugins.WebSearch.Presentation
```

Remove:

```elixir
Vibe.Plugins.WebSearch.*
```

No compatibility aliases. Eval alias `Web` can point to `Vibe.Plugins.WebSearch`.

## Implementation phases

### Phase 0: stop churn and clean partial work

- Remove/rename any accidental `Vibe.Storage.Representation.UIEvent`; use `Vibe.Storage.Representation.Event` if kept.
- Remove any storage snapshot names under `Vibe.Session.Store.*`.
- Keep no-compat rule.
- Ensure tests compile before starting the next slice.

### Phase 1: introduce protocols

Add:

```elixir
Vibe.Storage.Persistable
Vibe.Storage.Restorable
```

Use them on one vertical slice only.

### Phase 2: runtime alert vertical slice

Clean slice:

```text
Vibe.SystemAlarms.Alert
  -> Vibe.Event.RuntimeAlert.Set/Cleared payloads
  -> Vibe.Presentation.Presentable impl
  -> Vibe.Storage.Persistable impl
  -> Vibe.Storage.Representation.RuntimeAlert
  -> Vibe.Storage.Restorable impl
```

UI reducer consumes typed `Vibe.Event` payloads. Web/TUI consume presentation values. Storage persists through protocols.

### Phase 3: delete `Session.Store.Codec`

`Vibe.Session.Store.Codec` is a misnamed storage representation boundary. Delete it rather than shrinking it indefinitely.

Split by concern:

```elixir
Vibe.Storage.Representation.Event
Vibe.Storage.Representation.Trajectory
Vibe.Storage.Representation.EvalSnapshot
Vibe.Session.Store.TrajectoryProjection
```

Delete `Vibe.Session.Store.Codec` after the responsibilities move. Do not leave a compatibility facade.

### Phase 4: convert remaining event payloads

Order:

1. goals
2. tool events
3. model content/image refs
4. messages/assistant stream
5. notifications/status/session/plugin widgets
6. subagents/context compaction

### Phase 5: move web search

Move `Vibe.Plugins.WebSearch.*` into `Vibe.Plugins.WebSearch.*`. Delete old namespace with no aliases.

### Phase 6: presentation cleanup

Move domain-owned presentation modules into `Vibe.Presentation.*` and surface modules into `Vibe.TUI.Presentation.*` / `Vibe.Web.Presentation.*`.

## Reach architecture enforcement

This structure should be enforced by Reach architecture policy, not just convention.

Add/maintain `.reach.exs` and make `mix reach.check --arch` / `mix reach.check --smells --strict` part of release validation. No compatibility baseline for this refactor: fix violations or change the architecture intentionally.

Target Reach layers after the current namespaces are untangled:

```elixir
layers: [
  domain: [
    "Vibe.SystemAlarms.*",
    "Vibe.Tool.*",
    "Vibe.Model.*",
    "Vibe.Command.*",
    "Vibe.Goals.*",
    "Vibe.Files.*",
    "Vibe.Image",
    "Vibe.Code.*"
  ],
  event: "Vibe.Event.*",
  application: [
    "Vibe.Session*",
    "Vibe.SystemAlarms",
    "Vibe.Goals",
    "Vibe.Command",
    "Vibe.Plugin.*",
    "Vibe.Subagents.*"
  ],
  storage: [
    "Vibe.Storage.*",
    "Vibe.Memory",
    "Vibe.Telemetry",
    "Vibe.Session.Store*"
  ],
  presentation: "Vibe.Presentation.*",
  tui: "Vibe.TUI.*",
  web: "Vibe.Web.*",
  transport: "Vibe.Remote.*"
]
```

Layer rules should forbid representation leakage:

```elixir
deps: [
  forbidden: [
    {:domain, :storage},
    {:domain, :presentation},
    {:domain, :tui},
    {:domain, :web},
    {:domain, :transport},
    {:storage, :presentation},
    {:storage, :tui},
    {:storage, :web},
    {:presentation, :storage},
    {:presentation, :tui},
    {:presentation, :web},
    {:tui, :storage},
    {:web, :storage}
  ]
]
```

Call-level rules should ban random representation calls:

```elixir
calls: [
  forbidden: [
    {"Vibe.SystemAlarms.*", ["Jason.encode", "Jason.encode!", "Jason.decode", "Jason.decode!", "Vibe.Storage.*", "Vibe.Presentation.*"]},
    {"Vibe.Tool.*", ["Jason.encode", "Jason.encode!", "Jason.decode", "Jason.decode!", "Vibe.Storage.Representation.*"]},
    {"Vibe.UI.*", ["Vibe.Storage.Representation.*", "Vibe.Storage.Persistable.*", "Vibe.Storage.Restorable.*"]},
    {"Vibe.Web.*", ["Vibe.Storage.Representation.*", "Vibe.Storage.Persistable.*", "Vibe.Storage.Restorable.*"]},
    {"Vibe.TUI.*", ["Vibe.Storage.Representation.*", "Vibe.Storage.Persistable.*", "Vibe.Storage.Restorable.*"]},
    {"Vibe.Storage.*", ["Vibe.Presentation.*", "Vibe.TUI.*", "Vibe.Web.*"]}
  ]
]
```

Source rules should prevent removed namespaces from returning:

```elixir
source: [
  forbidden_modules: [
    "Vibe.UI.Event",
    "Vibe.UI.Event.*",
    "Vibe.UI.Bus",
    "Vibe.Plugins.WebSearch",
    "Vibe.Plugins.WebSearch.*",
    "Vibe.Session.Store.Codec",
    "Vibe.Actions.*",
    "Vibe.Tools.*",
    "Vibe.ToolOutput",
    "Vibe.ToolDisplay"
  ],
  forbidden_files: [
    "lib/vibe/web_search.ex",
    "lib/vibe/web_search/**",
    "lib/vibe/session/store/codec.ex"
  ]
]
```

Public/internal boundaries should make representation modules callable only through their boundary services:

```elixir
boundaries: [
  public: [
    "Vibe.Event",
    "Vibe.Event.Bus",
    "Vibe.Storage",
    "Vibe.Storage.Events",
    "Vibe.Presentation"
  ],
  internal: [
    "Vibe.Storage.Representation.*"
  ],
  internal_callers: [
    {"Vibe.Storage.Representation.*", ["Vibe.Storage.*"]}
  ]
]
```

Initial `.reach.exs` may start with call/source/internal-boundary rules while existing cyclic namespaces are being untangled. Do not treat empty/coarse layers as the final architecture. Tighten this policy as each slice lands. If a rule is too coarse, add precise `except:`/`internal_callers` entries rather than weakening the boundary.

## Test hierarchy rule

Tests must mirror the production hierarchy. When modules move from generic or UI-owned namespaces into semantic/event, storage, or presentation namespaces, tests move with them.

Examples:

```text
lib/vibe/event/runtime_alert/set.ex
  -> test/vibe/event/runtime_alert/set_test.exs

lib/vibe/storage/representation/runtime_alert.ex
  -> test/vibe/storage/representation/runtime_alert_test.exs

lib/vibe/presentation/runtime_alert.ex
  -> test/vibe/presentation/runtime_alert_test.exs

lib/vibe/plugins/web_search/search_result.ex
  -> test/vibe/plugins/web_search/search_result_test.exs
```

Avoid leaving tests under old conceptual locations such as `test/vibe/ui/*` when they are testing semantic event behavior, storage representation behavior, or plugin-owned web search behavior.

Reducer tests can stay under `test/vibe/ui/*` only when they test UI state derivation from semantic events.

Storage protocol tests should assert protocol dispatch and restored typed structs, not raw map shapes except at the explicit storage JSON boundary.

Presentation tests should assert renderer-neutral presentation values under `test/vibe/presentation/*`; TUI/Web tests should only assert surface projection under `test/vibe/tui/presentation/*` and `test/vibe/web/presentation/*`.

## Validation targets

For each slice:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test <focused tests>
```

After several slices:

```bash
mix test
mix credo --strict
mix dialyzer
```
