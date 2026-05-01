defimpl Exy.Markdown, for: Exy.Subagents.JobInfo do
  @moduledoc """
  Markdown rendering for subagent job summaries.
  """

  def to_markdown(job) do
    [
      "## Subagent job ",
      job.id,
      "\n\n",
      "- Status: `",
      to_string(job.status),
      "`\n",
      optional("- Role: `", job.role, "`\n"),
      optional("- Model: `", job.model, "`\n"),
      "- Child session: `",
      to_string(job.child_session_id),
      "`\n",
      optional("- Duration: `", job.duration_ms, "ms`\n"),
      "\n",
      job.task,
      result(job)
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp result(%{error: error}) when not is_nil(error),
    do: ["\n\n### Error\n\n", inspect(error, pretty: true)]

  defp result(%{result: result}) when not is_nil(result),
    do: ["\n\n### Result\n\n", Exy.Markdown.to_markdown(result)]

  defp result(_job), do: []
  defp optional(_prefix, nil, _suffix), do: []
  defp optional(prefix, value, suffix), do: [prefix, to_string(value), suffix]
end

defimpl Exy.Markdown, for: Exy.Subagents.Schedule do
  @moduledoc """
  Markdown rendering for scheduled subagent jobs.
  """

  def to_markdown(schedule) do
    [
      "## Subagent schedule ",
      schedule.id,
      "\n\n",
      optional("- Role: `", schedule.role, "`\n"),
      optional("- Next run: `", format_datetime(schedule.next_run_at), "`\n"),
      optional("- Every: `", schedule.every_ms, "ms`\n"),
      optional("- Missed: `", schedule.missed, "`\n"),
      "\n",
      schedule.task
    ]
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp optional(_prefix, nil, _suffix), do: []
  defp optional(prefix, value, suffix), do: [prefix, to_string(value), suffix]
  defp format_datetime(%DateTime{} = at), do: DateTime.to_iso8601(at)
  defp format_datetime(value), do: value
end
