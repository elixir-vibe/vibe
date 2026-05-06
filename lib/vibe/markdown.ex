defprotocol Vibe.Markdown do
  @moduledoc """
  Converts structured Vibe/plugin data into Markdown for eval, TUI, and web rendering.
  """

  @fallback_to_any true

  @spec to_markdown(t()) :: String.t()
  def to_markdown(term)
end
