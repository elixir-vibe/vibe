defimpl Vibe.Markdown, for: Vibe.Code.AST.Result do
  @moduledoc """
  Markdown rendering for structured AST search and replace results.
  """

  def to_markdown(%{action: :replace} = result) do
    params = [
      "- Action: `replace`",
      "- Path: `#{result.path}`",
      "- Pattern: `#{result.pattern}`",
      "- Replacement: `#{result.replacement}`",
      "- Dry run: `#{inspect(result.dry_run)}`"
    ]

    matches = ["- Matches: `#{match_count(result.result)}`"]

    diffs =
      result.diff
      |> List.wrap()
      |> Enum.map(fn %{path: path, diff: diff} ->
        "### #{path}\n\n```diff\n#{diff}\n```"
      end)

    Enum.join(
      ["## AST replace", Enum.join(params, "\n"), Enum.join(matches, "\n") | diffs],
      "\n\n"
    )
  end

  def to_markdown(%{action: action} = result) do
    """
    ## AST #{action}

    ```elixir
    #{inspect(result, pretty: true, limit: 50)}
    ```
    """
  end

  defp match_count(matches) when is_list(matches) do
    Enum.sum_by(matches, fn
      {_path, count} -> count
      _other -> 1
    end)
  end

  defp match_count(_matches), do: 0
end
