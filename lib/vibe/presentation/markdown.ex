defmodule Vibe.Presentation.Markdown do
  @moduledoc "Markdown rendering for renderer-neutral presentation values."

  @spec render(term()) :: String.t()
  def render(value) do
    case Vibe.Presentation.Markdown.Renderable.render(value) do
      markdown when is_binary(markdown) -> markdown
    end
  end
end
