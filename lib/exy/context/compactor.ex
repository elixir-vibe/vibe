defmodule Exy.Context.Compactor do
  @moduledoc "Internal implementation module."
  alias Exy.Context.Serializer
  alias Exy.Trajectory

  @type compact_result :: %{
          summary: String.t(),
          tokens_before: non_neg_integer(),
          kept_events: [Trajectory.t()],
          details: map()
        }

  @spec compact(keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(opts \\ []) do
    events = Keyword.get_lazy(opts, :events, fn -> Exy.Session.Store.trajectory(opts) end)
    compact(events, opts)
  end

  @spec compact([Trajectory.t()], keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(events, opts) when is_list(events) do
    keep_recent = Keyword.get(opts, :keep_recent, 12)
    previous_summary = Keyword.get(opts, :previous_summary) || latest_compaction_summary(events)
    events = drop_prior_compactions(events)

    {old_events, kept_events} = split_events(events, keep_recent)

    if old_events == [] do
      {:error, :nothing_to_compact}
    else
      with {:ok, summary} <- summarize(old_events, previous_summary, opts) do
        summary =
          summary <> Serializer.format_file_operations(Serializer.file_operations(old_events))

        event =
          Exy.Session.Store.append_trajectory(:compaction, %{
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
    ask_llm(prompt, Keyword.put(opts, :system, Exy.Prompts.summarization_system()))
  end

  @spec turn_prefix_summary([Trajectory.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def turn_prefix_summary(events, opts \\ []) do
    prompt =
      "<conversation>\n#{Serializer.serialize(events)}\n</conversation>\n\n" <>
        Exy.Prompts.turn_prefix_summary()

    ask_llm(prompt, Keyword.put(opts, :system, Exy.Prompts.summarization_system()))
  end

  defp ask_llm(prompt, opts) do
    ask = &Exy.Model.Direct.ask/2
    ask.(prompt, opts)
  end

  defp summary_request(events, previous_summary, opts) do
    custom = Keyword.get(opts, :custom_instructions)

    prompt =
      if previous_summary, do: Exy.Prompts.context_update(), else: Exy.Prompts.context_summary()

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

  defp split_events(events, keep_recent) do
    keep_recent = max(0, keep_recent)
    cut = max(length(events) - keep_recent, 0)
    Enum.split(events, cut)
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
