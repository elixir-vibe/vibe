defmodule Vibe.Tool.Display.Util do
  @moduledoc "Renderer-neutral helpers for semantic tool display documents."

  @spec tool_output(map()) :: term()
  def tool_output(tool) do
    tool
    |> Map.get(:output)
    |> unwrap_tool_output()
  end

  @spec arg(map(), atom()) :: term()
  def arg(args, key), do: Map.get(args, key) || Map.get(args, to_string(key))

  @spec expanded?(map()) :: boolean()
  def expanded?(tool), do: Map.get(tool, :expanded?, false) or Map.get(tool, :truncate?) == false

  @spec language_from_path(String.t() | nil) :: String.t()
  def language_from_path(path) when is_binary(path) do
    case Path.extname(path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".heex" -> "heex"
      ".css" -> "css"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".md" -> "markdown"
      extension -> String.trim_leading(extension, ".")
    end
  end

  def language_from_path(_path), do: "text"

  @spec path_summary(map(), term()) :: String.t() | nil
  def path_summary(tool, result) do
    path_from_args(tool) || path_from_result(result) || generic_summary(tool)
  end

  @spec markdown?(map()) :: boolean()
  def markdown?(%{language: language}) when is_binary(language),
    do: language in ["markdown", "md"]

  def markdown?(%{path: path}) when is_binary(path),
    do: String.downcase(Path.extname(path)) in [".md", ".markdown"]

  def markdown?(_result), do: false

  @spec read_limit_truncated?(map()) :: boolean()
  def read_limit_truncated?(result),
    do: Map.get(result, :omitted_lines, 0) > 0 or Map.get(result, :omitted_bytes, 0) > 0

  @spec generic_summary(map()) :: String.t()
  def generic_summary(tool) do
    tool
    |> Map.get(:name, "tool")
    |> to_string()
  end

  @spec timeout_arg(map()) :: term() | nil
  def timeout_arg(tool) do
    case Map.get(tool, :args) || %{} do
      %{timeout: timeout} -> timeout
      %{"timeout" => timeout} -> timeout
      _args -> nil
    end
  end

  @spec summarize_value(term(), pos_integer()) :: String.t()
  def summarize_value(value, limit) do
    value
    |> inspect(limit: 5, printable_limit: limit)
    |> String.slice(0, limit)
  end

  defp unwrap_tool_output(%{result: result}), do: result
  defp unwrap_tool_output(%{"result" => result}), do: result
  defp unwrap_tool_output(output), do: output

  @spec path_from_args(map()) :: String.t() | nil
  def path_from_args(%{args: %{path: path}}), do: path
  def path_from_args(_tool), do: nil

  @spec path_from_result(term()) :: String.t() | nil
  def path_from_result(%{path: path}), do: path
  def path_from_result(_result), do: nil
end
