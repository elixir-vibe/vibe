# Memory

Vibe keeps memory scopes separate so runtime scratch state does not accidentally become durable user memory.

| Memory | API | Purpose |
|---|---|---|
| Eval state | `Vibe.Eval.*` | Per-session variables, aliases, imports, and helper results |
| Agent scratch | `Vibe.Agent.Memory` | Ephemeral planning/runtime facts for a live agent process |
| Curated memory | `Vibe.Memory` / `Vibe.Memory.Manager` | Durable user/global/session facts intentionally recalled later |
| Session history | `Vibe.Session.Store` / `Vibe.Context` | Searchable conversation, tool, UI, and trajectory history |

Examples:

```elixir
Vibe.Memory.add(:user, "User prefers concise technical answers")
Vibe.Memory.add(:global, "For Vibe, run mix ci before commits")
Vibe.Memory.search("mix ci", scopes: [:user, :global])
Vibe.Memory.context_block("validation", scopes: [:user, :global])

Vibe.Agent.Memory.put(agent_id, :plan, "inspect docs")
Vibe.Agent.Memory.get(agent_id, :plan)
Vibe.Agent.Memory.clear(agent_id)
```

Recalled curated memory is inserted as background context, not direct user input. Session history can be searched, but important durable preferences should be promoted through `Vibe.Memory`.
