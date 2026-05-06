defmodule Vibe.MD.Doc do
  @moduledoc """
  Typed Markdown display value for eval and UI boundaries.
  """

  @type t :: %__MODULE__{markdown: String.t()}

  @enforce_keys [:markdown]
  defstruct [:markdown]
end

defimpl Vibe.Markdown, for: Vibe.MD.Doc do
  def to_markdown(doc), do: doc.markdown
end

defimpl String.Chars, for: Vibe.MD.Doc do
  def to_string(doc), do: doc.markdown
end
