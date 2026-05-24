defmodule Vibe.Event.EvalExecution do
  @moduledoc "Typed semantic event payloads for user-initiated Elixir evals."

  defmodule Started do
    @moduledoc "Payload emitted when a user eval starts."
    @enforce_keys [:id, :code, :include_context?]
    defstruct [:id, :code, :include_context?]
  end

  defmodule Finished do
    @moduledoc "Payload emitted when a user eval finishes."
    @enforce_keys [:id, :code, :include_context?, :status]
    defstruct [
      :id,
      :code,
      :include_context?,
      :status,
      :output,
      :output_format,
      :output_parts,
      :output_truncation,
      :error,
      :duration_ms
    ]
  end

  @spec started(map() | keyword()) :: Started.t()
  def started(attrs), do: attrs |> Map.new() |> then(&struct!(Started, &1))

  @spec finished(map() | keyword()) :: Finished.t()
  def finished(attrs), do: attrs |> Map.new() |> then(&struct!(Finished, &1))
end
