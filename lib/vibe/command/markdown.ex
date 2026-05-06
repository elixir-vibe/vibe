defimpl Vibe.Markdown, for: Vibe.Command.Result do
  @moduledoc """
  Markdown rendering for supervised command results.
  """

  def to_markdown(result) do
    [
      "## Command ",
      to_string(result.status),
      "\n\n",
      "- Command: `",
      Enum.join(result.argv, " "),
      "`\n",
      "- CWD: `",
      result.cwd,
      "`\n",
      "- Exit status: `",
      inspect(result.exit_status),
      "`\n",
      "- Duration: `",
      to_string(result.duration_ms),
      "ms`\n",
      "- Log: `",
      result.output_path,
      "`\n\n",
      "```text\n",
      String.trim_trailing(result.output),
      "\n```"
    ]
    |> IO.iodata_to_binary()
  end
end
