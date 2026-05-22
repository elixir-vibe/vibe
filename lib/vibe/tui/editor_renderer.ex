defmodule Vibe.TUI.EditorRenderer do
  @moduledoc "Renders the TUI prompt editor section."

  alias Vibe.Terminal.{Theme}
  alias Vibe.TUI.Widget

  @spec render(map(), Theme.t()) :: [IO.chardata()]
  def render(snapshot, theme) when is_map(snapshot) do
    Vibe.TUI.textarea(
      title: "Prompt",
      value: snapshot.editor.text,
      cursor: snapshot.editor.cursor,
      min_rows: min(max(snapshot.height - 8, 3), 8),
      placeholder: "Ask Vibe anything..."
    )
    |> Widget.render(snapshot.width, theme)
  end
end
