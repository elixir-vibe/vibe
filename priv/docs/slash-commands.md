# Slash commands

Type `/` in the TUI to open command autocomplete.

Built-in commands:

```text
/sessions  Browse and attach sessions
/session   Alias for /sessions
/s         Alias for /sessions
/new       Start a new session
/n         Alias for /new
/attach    Open session selector
/attach ID Attach by session id
/a ID      Alias for /attach ID
/model     Choose model
/skill     Choose skill
/clear     Clear visible messages
/compact   Compact context
/commands  Command palette
/help      Open built-in docs
/help NAME Open a specific help topic
```

Plugins can add slash commands by returning modules that implement `Exy.UI.SlashCommands.Command` from `Exy.Plugin.commands/1`.
