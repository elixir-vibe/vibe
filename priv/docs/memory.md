# Memory

Exy keeps memory scopes separate so runtime scratch state does not accidentally become durable user memory.

| Memory | API | Purpose |
|---|---|---|
| Eval state | `Exy.Eval.*` | Per-session variables, aliases, imports, and helper results |
| Agent scratch | `Exy.Agent.Memory` | Ephemeral planning/runtime facts for a live agent process |
| Curated memory | `Exy.Memory` / `Exy.Memory.Manager` | Durable user/global/session facts intentionally recalled later |
| Session history | `Exy.Session.Store` / `Exy.Context` | Searchable conversation, tool, UI, and trajectory history |

Examples:

```elixir
Exy.Memory.add(:user, "User prefers concise technical answers")
Exy.Memory.add(:global, "For Exy, run mix ci before commits")
Exy.Memory.search("mix ci", scopes: [:user, :global])
Exy.Memory.context_block("validation", scopes: [:user, :global])

Exy.Agent.Memory.put(agent_id, :plan, "inspect docs")
Exy.Agent.Memory.get(agent_id, :plan)
Exy.Agent.Memory.clear(agent_id)
```

Recalled curated memory is inserted as background context, not direct user input. Session history can be searched, but important durable preferences should be promoted through `Exy.Memory`.
