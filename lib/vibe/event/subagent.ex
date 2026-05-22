defmodule Vibe.Event.Subagent do
  @moduledoc "Typed semantic subagent lifecycle event payloads."

  defmodule Started do
    @moduledoc "Payload for a subagent starting."
    @enforce_keys [:id]
    defstruct [:id, :role, :model, :child_session_id, :parent_session_id, :task]

    @type t :: %__MODULE__{}
  end

  defmodule Finished do
    @moduledoc "Payload for a subagent finishing."
    @enforce_keys [:id, :status]
    defstruct [
      :id,
      :status,
      :role,
      :model,
      :child_session_id,
      :parent_session_id,
      :task,
      :result,
      :error,
      :pid,
      :started_at,
      :finished_at,
      :duration_ms
    ]

    @type t :: %__MODULE__{}
  end

  @spec started(map() | keyword()) :: Started.t()
  def started(attrs), do: attrs |> Map.new() |> then(&struct(Started, &1))

  @spec finished(map() | keyword()) :: Finished.t()
  def finished(attrs), do: attrs |> Map.new() |> then(&struct(Finished, &1))
end
