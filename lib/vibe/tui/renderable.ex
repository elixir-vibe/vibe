defprotocol Vibe.TUI.Renderable do
  @moduledoc "Protocol for rendering semantic UI values into TUI lines with stable cache keys."

  @spec render(t(), Vibe.TUI.RenderContext.t()) :: [IO.chardata()]
  def render(value, context)

  @spec render_key(t(), Vibe.TUI.RenderContext.t()) :: term()
  def render_key(value, context)
end
