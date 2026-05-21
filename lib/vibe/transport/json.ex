defmodule Vibe.Transport.JSON do
  @moduledoc "JSON projection for external transport payloads."

  @spec value(term()) :: term()
  def value(term), do: Vibe.Storage.JSON.value(term)
end
