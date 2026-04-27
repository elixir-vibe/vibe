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
      json_safe(value)
    else
      %{
        truncated: true,
        limit_bytes: max_bytes,
        output: limit_text(text, max_bytes)
      }
    end
  end

  defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_safe(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp json_safe(%Date{} = value), do: Date.to_iso8601(value)
  defp json_safe(%Time{} = value), do: Time.to_iso8601(value)
  defp json_safe(%_struct{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {json_safe_key(key), json_safe(value)} end)

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> json_safe()
  defp json_safe(pid) when is_pid(pid), do: inspect(pid)
  defp json_safe(reference) when is_reference(reference), do: inspect(reference)
  defp json_safe(value), do: value

  defp json_safe_key(key) when is_atom(key), do: key
  defp json_safe_key(key) when is_binary(key), do: key
  defp json_safe_key(key), do: inspect(key)
end
