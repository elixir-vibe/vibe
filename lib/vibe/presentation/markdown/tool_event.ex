defimpl Vibe.Markdown, for: Vibe.Tool.Event do
  @moduledoc "Markdown projection for semantic tool lifecycle events."

  def to_markdown(tool) do
    tool
    |> Vibe.Presentation.Presentable.present()
    |> Vibe.Presentation.Markdown.render()
  end
end
