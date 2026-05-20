defmodule Vibe.Context do
  @moduledoc """
  Context compaction for Vibe sessions.

  The compactor follows pi's structured checkpoint format: summarize old
  conversation/trajectory into a handoff that another model can use to continue,
  preserve critical file paths and errors, and append read/modified file lists.
  """

  alias Vibe.Context.{Compactor, Recall, Serializer}
  alias Vibe.Trajectory

  @type compact_result :: Compactor.compact_result()

  @doc "Intentional facade for the public Vibe API boundary."
  @spec compact(keyword()) :: {:ok, compact_result()} | {:error, term()}
  defdelegate compact(opts \\ []), to: Compactor

  @doc "Intentional facade for the public Vibe API boundary."
  @spec compact([Trajectory.t()], keyword()) :: {:ok, compact_result()} | {:error, term()}
  defdelegate compact(events, opts), to: Compactor

  @doc "Intentional facade for the public Vibe API boundary."
  @spec summarize([Trajectory.t()], String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, term()}
  defdelegate summarize(events, previous_summary \\ nil, opts \\ []), to: Compactor

  @doc "Intentional facade for the public Vibe API boundary."
  @spec turn_prefix_summary([Trajectory.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  defdelegate turn_prefix_summary(events, opts \\ []), to: Compactor

  @spec recall(String.t(), keyword()) :: String.t()
  def recall(query, opts \\ []), do: Recall.block(query, opts)

  @doc "Intentional facade for the public Vibe API boundary."
  @spec serialize([Trajectory.t()]) :: String.t()
  defdelegate serialize(events), to: Serializer
end
