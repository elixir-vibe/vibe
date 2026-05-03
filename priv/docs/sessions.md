# Sessions

Exy sessions are runtime objects owned by Exy, not just the current terminal. The goal is a tmux-like workflow: create sessions, send work to them, detach, and attach again later.

Common commands:

```bash
exy new
exy n
exy sessions
exy ls
exy send <session-id> "prompt"
exy attach <session-id>
exy a <session-id>
```

Inside eval:

```elixir
{:ok, session} = Exy.Session.start(session_id: "work")
{:ok, snapshot, cursor} = Exy.Session.attach(session)
Exy.Session.dispatch(session, {:submit_prompt, %{text: "hello"}})
Exy.Session.state(session)
Exy.Session.list()
Exy.Session.detach(session)
```

Durable session data is stored in SQLite:

```elixir
Exy.Session.Store.list()
Exy.Session.Store.ui_events("work")
Exy.Session.Store.trajectory(session_id: "work")
Exy.Session.search("sqlite migration", session_id: "work")
```

Plain `exy` opens the interactive TUI. Use `exy new` when you explicitly want a fresh session, and `exy attach <id>` when you want a specific existing session.

Interactive model controls:

```text
Ctrl+P        Cycle to the next model
Shift+Ctrl+P  Cycle to the previous model
Ctrl+L        Open the model selector
Shift+Tab     Cycle effort
```

Effort values are `off`, `minimal`, `low`, `medium`, `high`, and `xhigh`. The `/model` and `/effort` slash commands are aliases for the same session controls.
