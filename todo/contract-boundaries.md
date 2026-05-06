# Contract Boundary TODO

## Principle

String/atom flexibility belongs only at explicit external boundaries. Internal Vibe contracts should use structs or atom-keyed maps with bounded, documented fields.

## Remaining cleanup candidates

- `Vibe.Session.Store.Codec.atomize_keys/1`
  - Replace broad recursive key conversion with event-type-specific decoders.
  - Keep only known enum-value conversion for fields such as `:role`, `:status`, `:phase`, and `:lifecycle`.
- `Vibe.Tool.Display.Util.arg/2`
  - Keep mixed-key access only if it is explicitly documented as a tool-event display boundary.
  - Prefer normalizing tool call args once when converting external tool events into UI state.
- `Vibe.Skill.metadata`
  - Bound frontmatter keys to known metadata fields and keep unknown values in a separate `extra` map if needed.
- Plugin/script boundaries
  - Avoid broad `String.to_atom/1` or `String.to_existing_atom/1` outside known command/event names.

## Already addressed

- Auth provider dispatch is behaviour-driven instead of model-prefix conditionals in `Vibe.Model.Direct`.
- Provider usage extraction only accepts known usage fields.
- Code tool parameter keys are bounded in `Vibe.Code.AST` and `Vibe.Code.LSP`.
- Profile/subagent/scheduled-job option decoding accepts only known persisted keys.
