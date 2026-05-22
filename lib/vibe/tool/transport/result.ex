defmodule Vibe.Tool.Transport.Result do
  @moduledoc "Model-facing transport projection for generic tool results."

  @spec from_result(term()) :: term()
  def from_result(result), do: Vibe.Tool.Transport.JSON.value(result)
end
