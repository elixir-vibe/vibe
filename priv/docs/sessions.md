# Sessions

Vibe sessions are runtime objects owned by Vibe, not just the current terminal. The goal is a tmux-like workflow: create sessions, send work to them, detach, and attach again later.

Common commands:

```bash
vibe new
vibe n
vibe sessions
vibe ls
vibe send <session-id> "prompt"
vibe attach <session-id>
vibe a <session-id>
```

Inside eval:

```elixir
{:ok, session} = Vibe.Session.start(session_id: "work")
{:ok, snapshot, cursor} = Vibe.Session.attach(session)
Vibe.Session.dispatch(session, {:submit_prompt, %{text: "hello"}})
Vibe.Session.state(session)
Vibe.Session.list()
Vibe.Session.detach(session)
```

Durable session data is stored in SQLite:

```elixir
Vibe.Session.Store.list()
Vibe.Session.Store.ui_events("work")
Vibe.Session.Store.trajectory(session_id: "work")
Vibe.Session.search("sqlite migration", session_id: "work")
```

Plain `vibe` opens the interactive TUI. Use `vibe new` when you explicitly want a fresh session, and `vibe attach <id>` when you want a specific existing session.

Interactive model controls:

```text
Ctrl+P        Cycle to the next model
Shift+Ctrl+P  Cycle to the previous model
Ctrl+L        Open the model selector
Shift+Tab     Cycle effort
```

Effort values are `off`, `minimal`, `low`, `medium`, `high`, and `xhigh`. The `/model` and `/effort` slash commands are aliases for the same session controls.
