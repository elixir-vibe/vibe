defprotocol Exy.Markdown do
  @moduledoc """
  Converts structured Exy/plugin data into Markdown for eval, TUI, and web rendering.
  """

  @fallback_to_any true

  @spec to_markdown(t()) :: String.t()
  def to_markdown(term)
end
