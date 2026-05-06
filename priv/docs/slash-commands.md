# Slash commands

Type `/` in the TUI to open command autocomplete. Clipboard image paste is a keybinding (`Ctrl+V`), not a slash command.

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
/model     Open model selector (Ctrl+L)
/model ID  Select model by id
/effort    Open effort selector (Shift+Tab cycles effort)
/effort ID Select effort: off, minimal, low, medium, high, xhigh
/skill     Choose skill
/clear     Clear visible messages
/compact   Compact context
/commands  Command palette
/help      Open built-in docs
/help NAME Open a specific help topic
```

Plugins can add slash commands by returning modules that implement `Vibe.UI.SlashCommands.Command` from `Vibe.Plugin.commands/1`.
