defmodule Vibe.Presentation.Markdown do
  @moduledoc "Markdown rendering for renderer-neutral presentation values."

  @spec render(term()) :: String.t()
  def render(value), do: Vibe.Presentation.Markdown.Renderable.render(value)
end
