defmodule Vibe.Context.Compactor do
  @moduledoc """
  LLM-driven context compaction for long sessions.

  Uses token estimation (`chars / 4`) to find optimal cut points rather than
  fixed event counts. Walks backwards from the newest events, accumulating
  tokens until `keep_recent_tokens` is reached. The cut always lands on a
  user or assistant message boundary — never mid-tool-result.
  """

  alias Vibe.Context.Serializer
  alias Vibe.Trajectory

  @default_keep_tokens 20_000
  @valid_cut_types [:user_message, :assistant_message]

  @type compact_result :: %{
          summary: String.t(),
          tokens_before: non_neg_integer(),
          kept_events: [Trajectory.t()],
          details: map()
        }

  @spec compact(keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(opts \\ []) do
    events = Keyword.get_lazy(opts, :events, fn -> Vibe.Session.Store.trajectory(opts) end)
    compact(events, opts)
  end

  @spec compact([Trajectory.t()], keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(events, opts) when is_list(events) do
    keep_tokens = Keyword.get(opts, :keep_recent_tokens, @default_keep_tokens)
    previous_summary = Keyword.get(opts, :previous_summary) || latest_compaction_summary(events)
    events = drop_prior_compactions(events)

    {old_events, kept_events} = find_cut_point(events, keep_tokens)

    if old_events == [] do
      {:error, :nothing_to_compact}
    else
      with {:ok, summary} <- summarize(old_events, previous_summary, opts) do
        summary =
          summary <> Serializer.format_file_operations(Serializer.file_operations(old_events))

        event =
          Vibe.Session.Store.append_trajectory(:compaction, %{
            summary: summary,
            tokens_before: Serializer.estimate_tokens(events),
            kept_event_ids: Enum.map(kept_events, & &1.id),
            details: %{
              read_files: Serializer.read_files(old_events),
              modified_files: Serializer.modified_files(old_events)
            }
          })

        {:ok,
         %{
           summary: summary,
           tokens_before: Serializer.estimate_tokens(events),
           kept_events: kept_events,
           details: event.data.details
         }}
      end
    end
  end

  @spec summarize([Trajectory.t()], String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def summarize(events, previous_summary \\ nil, opts \\ []) do
    prompt = summary_request(events, previous_summary, opts)
    ask_llm(prompt, Keyword.put(opts, :system, Vibe.Prompts.summarization_system()))
  end

  @spec turn_prefix_summary([Trajectory.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def turn_prefix_summary(events, opts \\ []) do
    prompt =
      "<conversation>\n#{Serializer.serialize(events)}\n</conversation>\n\n" <>
        Vibe.Prompts.turn_prefix_summary()

    ask_llm(prompt, Keyword.put(opts, :system, Vibe.Prompts.summarization_system()))
  end

  defp ask_llm(prompt, opts) do
    ask = &Vibe.Model.Direct.ask/2
    ask.(prompt, opts)
  end

  defp summary_request(events, previous_summary, opts) do
    custom = Keyword.get(opts, :custom_instructions)

    prompt =
      if previous_summary, do: Vibe.Prompts.context_update(), else: Vibe.Prompts.context_summary()

    prompt = if custom, do: prompt <> "\n\nAdditional focus: " <> custom, else: prompt

    previous =
      if previous_summary do
        "\n\n<previous-summary>\n#{previous_summary}\n</previous-summary>"
      else
        ""
      end

    "<conversation>\n#{Serializer.serialize(events)}\n</conversation>" <>
      previous <> "\n\n" <> prompt
  end

  defp find_cut_point(events, keep_tokens) do
    reversed = Enum.reverse(events)

    {kept_reversed, _tokens} =
      Enum.reduce_while(reversed, {[], 0}, fn event, {acc, tokens} ->
        event_tokens = Serializer.event_tokens(event)
        new_tokens = tokens + event_tokens

        if new_tokens > keep_tokens and acc != [] do
          {:halt, {acc, tokens}}
        else
          {:cont, {[event | acc], new_tokens}}
        end
      end)

    kept = snap_to_boundary(kept_reversed)
    cut_index = length(events) - length(kept)
    Enum.split(events, max(cut_index, 0))
  end

  @spec find_cut_point_for_test([Trajectory.t()], non_neg_integer()) ::
          {[Trajectory.t()], [Trajectory.t()]}
  def find_cut_point_for_test(events, keep_tokens), do: find_cut_point(events, keep_tokens)

  @spec snap_to_boundary_for_test([Trajectory.t()]) :: [Trajectory.t()]
  def snap_to_boundary_for_test(events), do: snap_to_boundary(events)

  defp snap_to_boundary(events) do
    case Enum.find_index(events, &(&1.type in @valid_cut_types)) do
      nil -> events
      index -> Enum.drop(events, index)
    end
  end

  defp latest_compaction_summary(events) do
    events
    |> Enum.reverse()
    |> Enum.find_value(fn
      %Trajectory{type: :compaction, data: %{summary: summary}} -> summary
      _ -> nil
    end)
  end

  defp drop_prior_compactions(events), do: Enum.reject(events, &(&1.type == :compaction))
end
