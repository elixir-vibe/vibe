defmodule Exy.ToolOutput do
  @moduledoc """
  Context-safe limits for model-facing tool output.
  """

  @default_max_bytes 50_000
  @inspect_opts [charlists: :as_lists, limit: :infinity, printable_limit: :infinity, pretty: true]

  @spec default_max_bytes() :: pos_integer()
  def default_max_bytes, do: @default_max_bytes

  @spec limit_text(String.t(), pos_integer()) :: String.t()
  def limit_text(text, max_bytes \\ @default_max_bytes) when is_binary(text) do
    if byte_size(text) <= max_bytes do
      text
    else
      truncated_bytes = byte_size(text) - max_bytes

      text
      |> binary_part(0, max_bytes)
      |> Kernel.<>(
        "\n\n[tool output truncated: #{truncated_bytes} bytes omitted; limit=#{max_bytes} bytes]"
      )
    end
  end

  @spec limit_value(term(), pos_integer()) :: term()
  def limit_value(value, max_bytes \\ @default_max_bytes) do
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
end
