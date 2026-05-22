defmodule Vibe.Plugins.WebSearch.Presentation.FetchBody do
  @moduledoc false

  @spec markdown(map()) :: iodata()
  def markdown(%{format: :markdown, text: text}), do: text || ""

  def markdown(%{format: :html, text: text}) do
    text = text || ""

    case Vibe.Plugins.WebSearch.HTML.to_markdown(text) do
      {:ok, markdown} -> markdown
      {:error, _reason} -> fenced("html", text)
    end
  end

  def markdown(%{format: :json, text: text}), do: fenced("json", text)
  def markdown(%{text: text}), do: fenced("text", text)

  defp fenced(language, text), do: ["```", language, "\n", String.trim(text || ""), "\n```"]
end
