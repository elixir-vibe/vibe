defmodule Vibe.Presentation.Tool.Eval do
  @moduledoc "Semantic display builder for eval tool results."
  alias Vibe.Model.Content
  alias Vibe.Presentation.Tool, as: Display
  alias Vibe.Presentation.Tool.Util

  @spec from_tool(map()) :: Display.t()
  def from_tool(tool) do
    expanded? = Util.expanded?(tool)
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
    code_blocks =
      if expanded? and is_binary(code) and code != "",
        do: [{:source, code, language: :elixir}],
        else: []

    code_blocks ++ output_blocks(tool, output)
  end

  defp output_blocks(_tool, %{error: error}),
    do: [{:error, error |> to_string() |> trim_final_newline(), []}]

  defp output_blocks(%{output_parts: [_ | _] = parts}, _output) do
    parts |> Enum.map(&normalize_part/1) |> Enum.reject(&is_nil/1)
  end

  defp output_blocks(%{output_format: :markdown}, output) when is_binary(output),
    do: [{:markdown, trim_final_newline(output), truncation: :tail}]

  defp output_blocks(%{output_format: :inspect}, output) when not is_nil(output),
    do: [{:inspect, format_value(output), truncation: :tail}]

  defp output_blocks(tool, output) when is_binary(output),
    do: [{:text, trim_final_newline(output), truncation: output_truncation(tool)}]

  defp output_blocks(_tool, nil), do: []

  defp output_blocks(_tool, output),
    do: [{:inspect, format_value(output), truncation: :tail}]

  defp normalize_part(%Content.Text{text: text}) when text not in [nil, ""],
    do: {:text, trim_final_newline(text), truncation: :tail}

  defp normalize_part(%Content.Image{} = image), do: {:image, image, []}

  defp normalize_part(%{format: format, output: output}) when output not in [nil, ""] do
    {normalize_format(format), output |> format_value() |> trim_final_newline(),
     truncation: :tail}
  end

  defp normalize_part(%{"format" => format, "output" => output}) when output not in [nil, ""] do
    {normalize_format(format), output |> format_value() |> trim_final_newline(),
     truncation: :tail}
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

  defp trim_final_newline(text) when is_binary(text) do
    cond do
      String.ends_with?(text, "\r\n") -> String.slice(text, 0, byte_size(text) - 2)
      String.ends_with?(text, "\n") -> String.slice(text, 0, byte_size(text) - 1)
      true -> text
    end
  end

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
      args -> Util.summarize_value(args, 80)
    end
  end

  defp timeout_summary(tool) do
    case Util.timeout_arg(tool) do
      nil -> nil
      timeout -> format_timeout(timeout)
    end
  end

  defp format_timeout(timeout) when is_integer(timeout), do: format_milliseconds(timeout)
  defp format_timeout(timeout), do: to_string(timeout)

  defp format_milliseconds(milliseconds) when milliseconds < 1_000, do: "#{milliseconds}ms"

  defp format_milliseconds(milliseconds) when rem(milliseconds, 1_000) == 0,
    do: "#{div(milliseconds, 1_000)}s"

  defp format_milliseconds(milliseconds), do: "#{Float.round(milliseconds / 1_000, 1)}s"

  defp output_truncation(%{output_truncation: truncation}) when truncation in [:head, :tail],
    do: truncation

  defp output_truncation(_tool), do: :tail
end
