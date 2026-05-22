defmodule Vibe.Presentation.Markdown do
  @moduledoc "Markdown rendering for renderer-neutral presentation values."

  @spec render(term()) :: String.t()
  def render(value) do
    value
    |> Vibe.Presentation.Markdown.Renderable.render()
    |> ensure_markdown()
  end

  defp ensure_markdown(value) when is_binary(value), do: value
  defp ensure_markdown(value), do: to_string(value)
end
