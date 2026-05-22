defmodule Vibe.Presentation.Markdown.Fence do
  @moduledoc false

  @spec code_block(String.t(), String.t() | nil) :: iodata()
  def code_block(language, text) when is_binary(language) do
    text = String.trim(text || "")
    fence = fence_for(text)
    [fence, language, "\n", text, "\n", fence]
  end

  defp fence_for(text) do
    longest =
      ~r/`+/
      |> Regex.scan(text)
      |> Enum.map(fn [ticks] -> String.length(ticks) end)
      |> Enum.max(fn -> 2 end)

    String.duplicate("`", max(3, longest + 1))
  end
end
