defmodule Vibe.ToolOutput.Window do
  @moduledoc "Reusable line/byte windows for large model-facing tool output."

  alias Vibe.ToolOutput

  @default_max_lines 2_000

  defstruct [
    :text,
    :mode,
    :limit_bytes,
    :limit_lines,
    :total_bytes,
    :total_lines,
    :output_bytes,
    :output_lines,
    :full_output_path,
    :partial_line?,
    truncated?: false
  ]

  @type mode :: :head | :tail
  @type t :: %__MODULE__{
          text: String.t(),
          mode: mode(),
          limit_bytes: pos_integer(),
          limit_lines: pos_integer(),
          total_bytes: non_neg_integer(),
          total_lines: non_neg_integer(),
          output_bytes: non_neg_integer(),
          output_lines: non_neg_integer(),
          full_output_path: String.t() | nil,
          partial_line?: boolean(),
          truncated?: boolean()
        }

  @spec default_max_lines() :: pos_integer()
  def default_max_lines, do: @default_max_lines

  @spec build(String.t(), keyword()) :: t()
  def build(text, opts \\ []) when is_binary(text) and is_list(opts) do
    mode = normalize_mode(Keyword.get(opts, :mode, :head))

    limit_bytes =
      normalize_positive(Keyword.get(opts, :limit_bytes), ToolOutput.default_max_bytes())

    limit_lines = normalize_positive(Keyword.get(opts, :limit_lines), @default_max_lines)
    full_output_path = Keyword.get(opts, :full_output_path)
    total_bytes = byte_size(text)
    lines = String.split(text, "\n")
    total_lines = length(lines)

    if total_bytes <= limit_bytes and total_lines <= limit_lines do
      new(text, mode, limit_bytes, limit_lines, total_bytes, total_lines, full_output_path, false)
    else
      {visible, partial_line?} = take_window(lines, mode, limit_bytes, limit_lines)
      output = Enum.join(visible, "\n")

      %__MODULE__{
        text: output,
        mode: mode,
        limit_bytes: limit_bytes,
        limit_lines: limit_lines,
        total_bytes: total_bytes,
        total_lines: total_lines,
        output_bytes: byte_size(output),
        output_lines: length(visible),
        full_output_path: full_output_path,
        partial_line?: partial_line?,
        truncated?: true
      }
    end
  end

  @spec text_with_notice(String.t(), keyword()) :: String.t()
  def text_with_notice(text, opts \\ []) do
    window = build(text, opts)

    if window.truncated? do
      window.text <> "\n\n" <> notice(window)
    else
      window.text
    end
  end

  @spec notice(t()) :: String.t()
  def notice(%__MODULE__{truncated?: false}), do: ""

  def notice(%__MODULE__{} = window) do
    range = line_range(window)

    limit =
      if window.total_bytes > window.limit_bytes,
        do: " (#{format_size(window.limit_bytes)} limit)",
        else: ""

    path = if window.full_output_path, do: ". Full output: #{window.full_output_path}", else: ""

    if window.partial_line? do
      "[Showing #{format_size(window.output_bytes)} of #{format_size(window.total_bytes)}#{limit}#{path}]"
    else
      "[Showing lines #{range} of #{window.total_lines}#{limit}#{path}]"
    end
  end

  defp new(
         text,
         mode,
         limit_bytes,
         limit_lines,
         total_bytes,
         total_lines,
         full_output_path,
         truncated?
       ) do
    %__MODULE__{
      text: text,
      mode: mode,
      limit_bytes: limit_bytes,
      limit_lines: limit_lines,
      total_bytes: total_bytes,
      total_lines: total_lines,
      output_bytes: byte_size(text),
      output_lines: total_lines,
      full_output_path: full_output_path,
      partial_line?: false,
      truncated?: truncated?
    }
  end

  defp take_window(lines, :head, limit_bytes, limit_lines) do
    lines
    |> Enum.take(limit_lines)
    |> take_head_bytes(limit_bytes)
  end

  defp take_window(lines, :tail, limit_bytes, limit_lines) do
    lines
    |> Enum.take(-limit_lines)
    |> take_tail_bytes(limit_bytes)
  end

  defp take_head_bytes(lines, limit_bytes) do
    case take_complete_lines(lines, limit_bytes) do
      [] -> {[take_bytes(hd(lines) || "", limit_bytes, :head)], true}
      output -> {Enum.reverse(output), false}
    end
  end

  defp take_tail_bytes(lines, limit_bytes) do
    reversed_lines = Enum.reverse(lines)

    case take_complete_lines(reversed_lines, limit_bytes) do
      [] -> {[take_bytes(hd(reversed_lines) || "", limit_bytes, :tail)], true}
      output -> {output, false}
    end
  end

  defp take_complete_lines(lines, limit_bytes) do
    {visible, _bytes} =
      Enum.reduce_while(lines, {[], 0}, fn line, {acc, bytes} ->
        line_bytes = byte_size(line) + if(acc == [], do: 0, else: 1)

        if bytes + line_bytes <= limit_bytes do
          {:cont, {[line | acc], bytes + line_bytes}}
        else
          {:halt, {acc, bytes}}
        end
      end)

    visible
  end

  defp take_bytes(text, limit_bytes, direction) do
    text
    |> String.graphemes()
    |> take_graphemes(limit_bytes, direction)
    |> Enum.join()
  end

  defp take_graphemes(graphemes, limit_bytes, :head),
    do: take_graphemes_head(graphemes, limit_bytes, [])

  defp take_graphemes(graphemes, limit_bytes, :tail),
    do: graphemes |> Enum.reverse() |> take_graphemes_head(limit_bytes, []) |> Enum.reverse()

  defp take_graphemes_head([grapheme | rest], limit_bytes, acc) do
    next = [grapheme | acc]

    if next |> Enum.reverse() |> Enum.join() |> byte_size() <= limit_bytes do
      take_graphemes_head(rest, limit_bytes, next)
    else
      Enum.reverse(acc)
    end
  end

  defp take_graphemes_head([], _limit_bytes, acc), do: Enum.reverse(acc)

  defp line_range(%__MODULE__{mode: :head, output_lines: output_lines}) do
    "1-#{output_lines}"
  end

  defp line_range(%__MODULE__{mode: :tail, total_lines: total_lines, output_lines: output_lines}) do
    start_line = max(total_lines - output_lines + 1, 1)
    "#{start_line}-#{total_lines}"
  end

  defp normalize_mode(:tail), do: :tail
  defp normalize_mode(_mode), do: :head

  defp normalize_positive(value, _default) when is_integer(value) and value > 0, do: value
  defp normalize_positive(_value, default), do: default

  defp format_size(bytes) when bytes < 1_024, do: "#{bytes}B"

  defp format_size(bytes) when bytes < 1_048_576,
    do: :io_lib.format("~.1fKB", [bytes / 1_024]) |> IO.iodata_to_binary()

  defp format_size(bytes),
    do: :io_lib.format("~.1fMB", [bytes / 1_048_576]) |> IO.iodata_to_binary()
end
