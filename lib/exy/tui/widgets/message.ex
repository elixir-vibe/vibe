defmodule Exy.TUI.Widgets.Message do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: %{role: :user, text: text}}, width, theme) do
    prefix = Theme.fg(theme, :accent, "You: ")
    Widget.wrap([prefix, Theme.fg(theme, :user_message_text, to_string(text))], width)
  end

  def render(%{props: %{error: error}}, width, theme) when is_binary(error) do
    Widget.wrap(Theme.fg(theme, :error, ["Exy error: ", error]), width)
  end

  def render(%{props: %{role: :assistant} = props}, width, theme) do
    prefix = Theme.fg(theme, :success, "Exy: ")

    Widget.wrap(
      [prefix, Theme.fg(theme, :assistant_message_text, to_string(Map.get(props, :text) || ""))],
      width
    )
  end

  def render(%{props: %{text: text}}, width, theme) do
    prefix = Theme.fg(theme, :accent, "You: ")
    Widget.wrap([prefix, Theme.fg(theme, :user_message_text, to_string(text))], width)
  end
end
