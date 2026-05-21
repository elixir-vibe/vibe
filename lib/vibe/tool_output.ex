defmodule Vibe.ToolOutput do
  @moduledoc """
  Context-safe limits for model-facing tool output.
  """

  @default_max_bytes 50_000
  @inspect_opts [charlists: :as_lists, limit: :infinity, printable_limit: :infinity, pretty: true]

  @spec default_max_bytes() :: pos_integer()
  def default_max_bytes, do: @default_max_bytes

  @spec limit_text(String.t(), pos_integer() | keyword()) :: String.t()
  def limit_text(text, opts \\ @default_max_bytes)

  def limit_text(text, max_bytes) when is_binary(text) and is_integer(max_bytes) do
    text |> limit_text_result(max_bytes) |> Map.fetch!(:text)
  end

  def limit_text(text, opts) when is_binary(text) and is_list(opts) do
    Vibe.ToolOutput.Window.text_with_notice(text, opts)
  end

  @spec limit_text_result(String.t(), pos_integer() | keyword()) :: %{
          text: String.t(),
          omitted_bytes: non_neg_integer(),
          limit_bytes: pos_integer(),
          truncated?: boolean()
        }
  def limit_text_result(text, opts \\ @default_max_bytes)

  def limit_text_result(text, max_bytes) when is_binary(text) and is_integer(max_bytes) do
    max_bytes = normalize_max_bytes(max_bytes)

    if byte_size(text) <= max_bytes do
      %{text: text, omitted_bytes: 0, limit_bytes: max_bytes, truncated?: false}
    else
      omitted_bytes = byte_size(text) - max_bytes

      limited =
        binary_part(text, 0, max_bytes) <>
          "\n\n[tool output truncated: #{omitted_bytes} bytes omitted; limit=#{max_bytes} bytes]"

      %{text: limited, omitted_bytes: omitted_bytes, limit_bytes: max_bytes, truncated?: true}
    end
  end

  def limit_text_result(text, opts) when is_binary(text) and is_list(opts) do
    window = Vibe.ToolOutput.Window.build(text, opts)

    %{
      text: Vibe.ToolOutput.Window.text_with_notice(text, opts),
      omitted_bytes: max(window.total_bytes - window.output_bytes, 0),
      limit_bytes: window.limit_bytes,
      truncated?: window.truncated?
    }
  end

  @spec limit_content(String.t(), keyword()) :: %{
          content: String.t(),
          omitted_lines: non_neg_integer(),
          omitted_bytes: non_neg_integer(),
          truncated?: boolean()
        }
  def limit_content(content, opts \\ []) when is_binary(content) and is_list(opts) do
    limit_lines = Keyword.get(opts, :limit_lines, :infinity)
    byte_result = limit_text_result(content, Keyword.get(opts, :limit_bytes, @default_max_bytes))
    lines = String.split(byte_result.text, "\n")

    if is_integer(limit_lines) and limit_lines > 0 and length(lines) > limit_lines do
      visible = lines |> Enum.take(limit_lines) |> Enum.join("\n")

      %{
        content: visible,
        omitted_lines: length(lines) - limit_lines,
        omitted_bytes: byte_result.omitted_bytes,
        truncated?: true
      }
    else
      %{
        content: byte_result.text,
        omitted_lines: 0,
        omitted_bytes: byte_result.omitted_bytes,
        truncated?: byte_result.truncated?
      }
    end
  end

  @spec limit_value(term(), pos_integer()) :: term()
  def limit_value(value, max_bytes \\ @default_max_bytes) do
    max_bytes = normalize_max_bytes(max_bytes)
    text = inspect(value, @inspect_opts)

    if byte_size(text) <= max_bytes do
      value
    else
      %{
        truncated: true,
        limit_bytes: max_bytes,
        output: limit_text(text, max_bytes)
      }
    end
  end

  defp normalize_max_bytes(max_bytes) when is_integer(max_bytes) and max_bytes > 0,
    do: max_bytes

  defp normalize_max_bytes(_max_bytes), do: @default_max_bytes
end
