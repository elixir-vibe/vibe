defmodule Vibe.Tool.Transport.JSON do
  @moduledoc "JSON projection for model-facing tool transport payloads."

  @spec value(term()) :: term()
  def value(term), do: Vibe.Tool.Transport.JSON.Encodable.value(term)
end
