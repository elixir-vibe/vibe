defmodule Vibe.Tool.Transport.ReadResult do
  @moduledoc "Model-facing transport projection for read tool results."

  alias Vibe.Files.ReadResult

  @spec from_read_result(ReadResult.t()) :: map()
  def from_read_result(%ReadResult{} = result) do
    result
    |> Map.from_struct()
    |> Map.delete(:__content_parts__)
    |> Map.new(fn {key, value} -> {key, Vibe.Tool.Transport.JSON.value(value)} end)
    |> Map.put(:content_type, result.content_type)
    |> Map.put(:__content_parts__, result.__content_parts__)
  end
end
