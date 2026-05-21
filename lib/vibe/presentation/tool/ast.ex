defmodule Vibe.Presentation.Tool.AST do
  @moduledoc "Semantic display document for AST tool results."

  alias Vibe.Presentation.Tool, as: Display
  alias Vibe.Presentation.Tool.Util

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    %Display{
      name: :ast,
      status: Map.get(tool, :status),
      summary: summary(tool, result),
      meta: meta(tool, result),
      body: body(tool, result),
      expanded?: Util.expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp summary(tool, result) do
    action = tool |> Map.get(:args, %{}) |> Util.arg(:action)
    count = if is_list(result), do: length(result), else: nil

    [action, count && "#{count} matches"]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
  end

  defp meta(tool, result) do
    [action(tool), is_list(result) && "#{length(result)} results"]
    |> Enum.reject(&(&1 in [nil, false, ""]))
  end

  defp body(_tool, %Vibe.Code.AST.Result{action: :replace} = result) do
    params = replace_params(result)

    diffs =
      Enum.map(result.diff || [], &{:diff, &1.diff, language: Util.language_from_path(&1.path)})

    [{:text, params, truncation: :tail} | diffs]
  end

  defp body(tool, %Vibe.Code.AST.Result{action: :search} = result) do
    body(tool, result.result)
  end

  defp body(tool, result) when is_list(result) do
    args = Map.get(tool, :args) || %{}
    pattern = Util.arg(args, :pattern)
    header = if pattern, do: ["pattern: ", pattern, "\n"], else: []
    matches = Enum.map_join(result, "\n", &format_match/1)
    [{:text, IO.iodata_to_binary([header, matches]), truncation: :tail}]
  end

  defp body(_tool, result), do: [{:inspect, inspect(result, pretty: true), []}]

  defp replace_params(result) do
    [
      "path: ",
      to_string(result.path),
      "\npattern: ",
      to_string(result.pattern),
      "\nreplacement: ",
      to_string(result.replacement),
      if(result.dry_run, do: "\ndry-run", else: "")
    ]
    |> IO.iodata_to_binary()
  end

  defp format_match(%{path: path, line: line}), do: "#{path}:#{line}"
  defp format_match(%{file: path, line: line}), do: "#{path}:#{line}"
  defp format_match(match), do: inspect(match, pretty: true)

  defp action(tool) do
    args = Map.get(tool, :args) || %{}

    case Util.arg(args, :action) do
      nil -> nil
      action -> to_string(action)
    end
  end
end
