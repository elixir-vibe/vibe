defmodule Exy.Tool.Display.Eval do
  @moduledoc false

  alias Exy.Tool.Display
  alias Exy.TUI.Duration

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    expanded? = expanded?(tool)
    code = code_from_tool(tool)
    output = output(tool)

    %Display{
      name: :eval,
      status: Map.get(tool, :status),
      summary: if(expanded?, do: nil, else: code || fallback_summary(tool)),
      summary_style: if(is_binary(code) and not expanded?, do: :elixir_dim),
      meta: [timeout_summary(tool)],
      body: body(tool, code, output, expanded?),
      expanded?: expanded?,
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp body(tool, code, output, expanded?) do
    []
    |> maybe_add_code(code, expanded?)
    |> add_output_blocks(tool, output)
  end

  defp maybe_add_code(blocks, code, true) when is_binary(code) and code != "",
    do: blocks ++ [{:source, code, language: :elixir}]

  defp maybe_add_code(blocks, _code, _expanded?), do: blocks

  defp add_output_blocks(blocks, _tool, %{error: error}),
    do: blocks ++ [{:error, to_string(error), []}]

  defp add_output_blocks(blocks, %{output_parts: [_ | _] = parts}, _output) do
    blocks ++ (parts |> Enum.map(&normalize_part/1) |> Enum.reject(&is_nil/1))
  end

  defp add_output_blocks(blocks, %{output_format: :markdown}, output) when is_binary(output),
    do: blocks ++ [{:markdown, output, truncation: :tail}]

  defp add_output_blocks(blocks, %{output_format: :inspect}, output) when not is_nil(output),
    do: blocks ++ [{:inspect, format_value(output), truncation: :tail}]

  defp add_output_blocks(blocks, _tool, output) when is_binary(output),
    do: blocks ++ [{:text, output, truncation: :tail}]

  defp add_output_blocks(blocks, _tool, nil), do: blocks

  defp add_output_blocks(blocks, _tool, output),
    do: blocks ++ [{:inspect, format_value(output), truncation: :tail}]

  defp normalize_part(%{format: format, output: output}) when output not in [nil, ""] do
    {normalize_format(format), format_value(output), truncation: :tail}
  end

  defp normalize_part(%{"format" => format, "output" => output}) when output not in [nil, ""] do
    {normalize_format(format), format_value(output), truncation: :tail}
  end

  defp normalize_part(_part), do: nil

  defp normalize_format(:markdown), do: :markdown
  defp normalize_format("markdown"), do: :markdown
  defp normalize_format(:inspect), do: :inspect
  defp normalize_format("inspect"), do: :inspect
  defp normalize_format(_format), do: :text

  defp output(tool) do
    case Map.get(tool, :output) || Map.get(tool, :result) do
      %{output: output} -> output
      output -> output
    end
  end

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value, pretty: true, limit: 20)

  defp code_from_tool(tool) do
    cond do
      code = Map.get(tool, :code) -> code
      args = Map.get(tool, :args) -> code_from_args(args)
      true -> nil
    end
  end

  defp code_from_args(%{code: code}), do: code
  defp code_from_args(%{"code" => code}), do: code
  defp code_from_args(_args), do: nil

  defp fallback_summary(tool) do
    case Map.get(tool, :args) || Map.get(tool, :params) do
      nil -> nil
      args -> Exy.TUI.ToolWidget.summarize_value(args, 80)
    end
  end

  defp timeout_summary(tool) do
    case Map.get(tool, :args) || %{} do
      %{timeout: timeout} -> format_timeout(timeout)
      %{"timeout" => timeout} -> format_timeout(timeout)
      _args -> nil
    end
  end

  defp format_timeout(timeout) when is_integer(timeout), do: Duration.milliseconds(timeout)
  defp format_timeout(timeout), do: to_string(timeout)

  defp expanded?(tool), do: Map.get(tool, :expanded?, false) or Map.get(tool, :truncate?) == false
end
