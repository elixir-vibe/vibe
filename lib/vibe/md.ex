defmodule Vibe.MD do
  @moduledoc """
  Eval-friendly Markdown rendering helpers.
  """

  alias Vibe.MD.Doc

  @spec to_markdown(term()) :: String.t()
  def to_markdown(term), do: Vibe.Markdown.to_markdown(term)

  @spec doc(term()) :: Doc.t()
  def doc(term), do: %Doc{markdown: to_markdown(term)}

  @spec puts(term()) :: term()
  def puts(term) do
    IO.puts(to_markdown(term))
    term
  end

  @spec code(String.t(), String.t() | nil) :: String.t()
  def code(text, language \\ nil) when is_binary(text) do
    fence = "```"
    lang = language || ""
    [fence, lang, "\n", text, "\n", fence] |> IO.iodata_to_binary()
  end

  @spec section(String.t(), term()) :: String.t()
  def section(title, body), do: ["## ", title, "\n\n", to_markdown(body)] |> IO.iodata_to_binary()

  @spec join([term()]) :: String.t()
  def join(items), do: Enum.map_join(items, "\n\n", &to_markdown/1)
end
