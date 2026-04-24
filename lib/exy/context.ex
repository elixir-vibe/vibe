defmodule Exy.Context do
  @moduledoc """
  Context compaction for Exy sessions.

  The compactor follows pi's structured checkpoint format: summarize old
  conversation/trajectory into a handoff that another model can use to continue,
  preserve critical file paths and errors, and append read/modified file lists.
  """

  alias Exy.Trajectory

  @system_prompt """
  You are a context summarization assistant. Your task is to read a conversation between a user and an AI coding assistant, then produce a structured summary following the exact format specified.

  Do NOT continue the conversation. Do NOT respond to any questions in the conversation. ONLY output the structured summary.
  """

  @summary_prompt """
  The messages above are a conversation to summarize. Create a structured context checkpoint summary that another LLM will use to continue the work.

  Use this EXACT format:

  ## Goal
  [What is the user trying to accomplish? Can be multiple items if the session covers different tasks.]

  ## Constraints & Preferences
  - [Any constraints, preferences, or requirements mentioned by user]
  - [Or "(none)" if none were mentioned]

  ## Progress
  ### Done
  - [x] [Completed tasks/changes]

  ### In Progress
  - [ ] [Current work]

  ### Blocked
  - [Issues preventing progress, if any]

  ## Key Decisions
  - **[Decision]**: [Brief rationale]

  ## Next Steps
  1. [Ordered list of what should happen next]

  ## Critical Context
  - [Any data, examples, or references needed to continue]
  - [Or "(none)" if not applicable]

  Keep each section concise. Preserve exact file paths, function names, and error messages.
  """

  @update_prompt """
  The messages above are NEW conversation messages to incorporate into the existing summary provided in <previous-summary> tags.

  Update the existing structured summary with new information. RULES:
  - PRESERVE all existing information from the previous summary
  - ADD new progress, decisions, and context from the new messages
  - UPDATE the Progress section: move items from "In Progress" to "Done" when completed
  - UPDATE "Next Steps" based on what was accomplished
  - PRESERVE exact file paths, function names, and error messages
  - If something is no longer relevant, you may remove it

  Use this EXACT format:

  ## Goal
  [Preserve existing goals, add new ones if the task expanded]

  ## Constraints & Preferences
  - [Preserve existing, add new ones discovered]

  ## Progress
  ### Done
  - [x] [Include previously done items AND newly completed items]

  ### In Progress
  - [ ] [Current work - update based on progress]

  ### Blocked
  - [Current blockers - remove if resolved]

  ## Key Decisions
  - **[Decision]**: [Brief rationale] (preserve all previous, add new)

  ## Next Steps
  1. [Update based on current state]

  ## Critical Context
  - [Preserve important context, add new if needed]

  Keep each section concise. Preserve exact file paths, function names, and error messages.
  """

  @turn_prefix_prompt """
  This is the PREFIX of a turn that was too large to keep. The SUFFIX (recent work) is retained.

  Summarize the prefix to provide context for the retained suffix:

  ## Original Request
  [What did the user ask for in this turn?]

  ## Early Progress
  - [Key decisions and work done in the prefix]

  ## Context for Suffix
  - [Information needed to understand the retained recent work]

  Be concise. Focus on what's needed to understand the kept suffix.
  """

  @tool_result_max_chars 2_000

  @type compact_result :: %{
          summary: String.t(),
          tokens_before: non_neg_integer(),
          kept_events: [Trajectory.t()],
          details: map()
        }

  @spec compact(keyword()) :: {:ok, compact_result()} | {:error, term()}
  def compact(opts \\ []) do
    events = Keyword.get_lazy(opts, :events, fn -> Exy.Trajectory.Store.list(opts) end)
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
        summary = summary <> format_file_operations(file_operations(old_events))

        event =
          Exy.Trajectory.Store.append(:compaction, %{
            summary: summary,
            tokens_before: estimate_tokens(events),
            kept_event_ids: Enum.map(kept_events, & &1.id),
            details: %{
              read_files: read_files(old_events),
              modified_files: modified_files(old_events)
            }
          })

        {:ok,
         %{
           summary: summary,
           tokens_before: estimate_tokens(events),
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
    Exy.LLM.ask(prompt, Keyword.put(opts, :system, @system_prompt))
  end

  @spec turn_prefix_summary([Trajectory.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def turn_prefix_summary(events, opts \\ []) do
    prompt = "<conversation>\n#{serialize(events)}\n</conversation>\n\n" <> @turn_prefix_prompt
    Exy.LLM.ask(prompt, Keyword.put(opts, :system, @system_prompt))
  end

  @spec serialize([Trajectory.t()]) :: String.t()
  def serialize(events) do
    events
    |> Enum.map(&serialize_event/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp summary_request(events, previous_summary, opts) do
    custom = Keyword.get(opts, :custom_instructions)
    prompt = if previous_summary, do: @update_prompt, else: @summary_prompt
    prompt = if custom, do: prompt <> "\n\nAdditional focus: " <> custom, else: prompt

    previous =
      if previous_summary do
        "\n\n<previous-summary>\n#{previous_summary}\n</previous-summary>"
      else
        ""
      end

    "<conversation>\n#{serialize(events)}\n</conversation>" <> previous <> "\n\n" <> prompt
  end

  defp serialize_event(%Trajectory{type: :user_message, data: %{prompt: prompt}}),
    do: "[User]: #{prompt}"

  defp serialize_event(%Trajectory{type: :assistant_message, data: %{result: result}}) do
    "[Assistant]: #{truncate(inspect(result, pretty: true, limit: 50), @tool_result_max_chars)}"
  end

  defp serialize_event(%Trajectory{type: :tool_call, data: data}) do
    name =
      Map.get(data, :name) || Map.get(data, "name") || Map.get(data, :action) ||
        Map.get(data, "action")

    args =
      Map.get(data, :args) || Map.get(data, "args") ||
        Map.drop(data, [:name, "name", :result, "result"])

    "[Assistant tool call]: #{name}(#{inspect(args, limit: 20)})"
  end

  defp serialize_event(%Trajectory{type: :tool_result, data: %{result: result}}) do
    "[Tool result]: #{truncate(inspect(result, pretty: true, limit: 50), @tool_result_max_chars)}"
  end

  defp serialize_event(%Trajectory{type: :compaction, data: %{summary: summary}}) do
    "[Prior compaction summary]: #{summary}"
  end

  defp serialize_event(%Trajectory{type: type, data: data}) do
    "[#{type}]: #{truncate(inspect(data, pretty: true, limit: 50), @tool_result_max_chars)}"
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

  defp estimate_tokens(events), do: div(String.length(serialize(events)), 4)

  defp file_operations(events) do
    %{read: MapSet.new(read_files(events)), modified: MapSet.new(modified_files(events))}
  end

  defp read_files(events), do: file_paths(events, [:read, :read_file]) -- modified_files(events)
  defp modified_files(events), do: file_paths(events, [:edit, :write, :replace])

  defp file_paths(events, actions) do
    events
    |> Enum.flat_map(fn event ->
      action = get_in(event.data, [:action]) || get_in(event.data, ["action"])
      path = get_in(event.data, [:path]) || get_in(event.data, ["path"])

      if action in actions and is_binary(path), do: [path], else: []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp format_file_operations(%{read: read, modified: modified}) do
    sections = []

    sections =
      if MapSet.size(read) > 0,
        do: ["<read-files>\n#{Enum.join(read, "\n")}\n</read-files>" | sections],
        else: sections

    sections =
      if MapSet.size(modified) > 0,
        do: ["<modified-files>\n#{Enum.join(modified, "\n")}\n</modified-files>" | sections],
        else: sections

    case Enum.reverse(sections) do
      [] -> ""
      sections -> "\n\n" <> Enum.join(sections, "\n\n")
    end
  end

  defp truncate(text, max_chars) when byte_size(text) <= max_chars, do: text

  defp truncate(text, max_chars) do
    truncated = byte_size(text) - max_chars
    binary_part(text, 0, max_chars) <> "\n\n[... #{truncated} more characters truncated]"
  end
end
