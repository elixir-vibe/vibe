defmodule Vibe.TUI.Shortcuts do
  @moduledoc "Keybinding-to-action mapping for the TUI."
  alias Vibe.Terminal.Theme

  @shortcuts %{
    toggle_truncation: %{key: "ctrl+o", label: "expand"},
    cancel: %{key: "esc", label: "cancel"},
    quit: %{key: "ctrl+c ctrl+c", label: "quit"}
  }

  @spec get!(atom()) :: map()
  def get!(action), do: Map.fetch!(@shortcuts, action)

  @spec key(atom()) :: String.t()
  def key(action), do: get!(action).key

  @spec hint(atom(), Theme.t(), keyword()) :: IO.chardata()
  def hint(action, theme, opts \\ []) do
    shortcut = get!(action)
    label = Keyword.get(opts, :label, shortcut.label)

    [
      Theme.fg(theme, :accent, shortcut.key),
      Theme.fg(theme, :muted, [" to ", label])
    ]
  end
end
