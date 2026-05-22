# Contract Boundary TODO

## Principle

String/atom flexibility belongs only at explicit external boundaries. Internal Vibe contracts should use structs or atom-keyed maps with bounded, documented fields.

## Remaining cleanup candidates

- `Vibe.Presentation.Tool.Util.arg/2`
  - Keep mixed-key access only if it is explicitly documented as a tool-event display boundary.
  - Prefer normalizing tool call args once when converting external tool events into UI state.
- `Vibe.Skill.metadata`
  - Bound frontmatter keys to known metadata fields and keep unknown values in a separate `extra` map if needed.
- Plugin/script boundaries
  - Avoid broad `String.to_atom/1` or `String.to_existing_atom/1` outside known command/event names.

## Already addressed

- Plugin tool hooks now use typed `Vibe.Tool.PluginCall` and `Vibe.Tool.PluginResult` payload structs instead of ad-hoc execution maps.
- Session command intents now live at `Vibe.Session.Command.Intent`, outside `Vibe.UI`.
- Session command handling, event emission, and replay responsibilities are isolated under focused `Vibe.Session.*` internal modules.
- Storage event decoding now lives under typed `Vibe.Storage.Representation.*` modules; the old broad `Vibe.Session.Store.Codec` boundary was deleted.
- Plugin manager pipeline, callback execution, and collection helpers are isolated under focused `Vibe.Plugin.Manager.*` internal modules.
- Remote and gateway modules are guarded from `Vibe.UI.*` dependencies through Reach.
- Auth provider dispatch is behaviour-driven instead of model-prefix conditionals in `Vibe.Model.Direct`.
- Provider usage extraction only accepts known usage fields.
- Code tool parameter keys are bounded in `Vibe.Code.AST` and `Vibe.Code.LSP`.
- Profile/subagent/scheduled-job option decoding accepts only known persisted keys.
