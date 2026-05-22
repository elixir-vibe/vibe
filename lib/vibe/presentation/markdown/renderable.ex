defprotocol Vibe.Presentation.Markdown.Renderable do
  @moduledoc "Renders presentation values as Markdown."
  @fallback_to_any true

  @spec render(t()) :: String.t()
  def render(value)
end

defimpl Vibe.Presentation.Markdown.Renderable, for: Any do
  def render(value), do: Vibe.Markdown.to_markdown(value)
end
