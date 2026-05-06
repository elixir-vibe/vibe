defmodule Vibe.Code.AST.TextDiff do
  @moduledoc "Line-level text diff for AST replace previews."
  @spec unified(String.t(), String.t(), String.t()) :: String.t()
  def unified(old_source, new_source, path \\ "source") do
    old_lines = String.split(old_source, "\n")
    new_lines = String.split(new_source, "\n")

    Enum.join(["--- #{path}", "+++ #{path}", "@@" | diff_lines(old_lines, new_lines)], "\n")
  end

  defp diff_lines(old_lines, new_lines) do
    old_lines
    |> List.myers_difference(new_lines)
    |> Enum.flat_map(fn
      {:eq, lines} -> Enum.map(lines, &" #{&1}")
      {:del, lines} -> Enum.map(lines, &"-#{&1}")
      {:ins, lines} -> Enum.map(lines, &"+#{&1}")
    end)
  end
end
