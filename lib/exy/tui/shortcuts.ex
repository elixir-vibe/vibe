defmodule Exy.TUI.Shortcuts do
  @moduledoc "Internal implementation module."
  alias Exy.TUI.Theme

  @shortcuts %{
    toggle_truncation: %{key: "ctrl+o", label: "expand"},
    cancel: %{key: "esc", label: "cancel"},
    quit: %{key: "ctrl+c ctrl+c", label: "quit"}
  }

  @spec get!(atom()) :: map()
  def get!(action), do: Map.fetch!(@shortcuts, action)

  @spec key(atom()) :: String.t()
  def key(action), do: get!(action).key

  @spec hint(atom(), Exy.TUI.Theme.t(), keyword()) :: IO.chardata()
  def hint(action, theme, opts \\ []) do
    shortcut = get!(action)
    label = Keyword.get(opts, :label, shortcut.label)

    [
      Theme.fg(theme, :accent, shortcut.key),
      Theme.fg(theme, :muted, [" to ", label])
    ]
  end
end
