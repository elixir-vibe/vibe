defmodule Exy.Context do
  @moduledoc """
  Context compaction for Exy sessions.

  The compactor follows pi's structured checkpoint format: summarize old
  conversation/trajectory into a handoff that another model can use to continue,
  preserve critical file paths and errors, and append read/modified file lists.
  """

  alias Exy.Context.{Compactor, Recall, Serializer}
  alias Exy.Trajectory

  @type compact_result :: Compactor.compact_result()

  @spec compact(keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(opts \\ []), do: Compactor.compact(opts)

  @spec compact([Trajectory.t()], keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(events, opts), do: Compactor.compact(events, opts)

  @spec summarize([Trajectory.t()], String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def summarize(events, previous_summary \\ nil, opts \\ []),
    do: Compactor.summarize(events, previous_summary, opts)

  @spec turn_prefix_summary([Trajectory.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def turn_prefix_summary(events, opts \\ []), do: Compactor.turn_prefix_summary(events, opts)

  @spec recall(String.t(), keyword()) :: String.t()
  def recall(query, opts \\ []), do: Recall.block(query, opts)

  @spec serialize([Trajectory.t()]) :: String.t()
  def serialize(events), do: Serializer.serialize(events)
end
