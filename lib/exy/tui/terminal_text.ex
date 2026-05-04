defmodule Exy.TUI.TerminalText do
  @moduledoc "ANSI escape and control character sanitizer for display."
  @escape 0x1B
  @bell 0x07

  @spec sanitize(IO.chardata()) :: String.t()
  def sanitize(text) do
    text
    |> IO.iodata_to_binary()
    |> sanitize_binary([])
    |> IO.iodata_to_binary()
  end

  defp sanitize_binary(<<>>, acc), do: Enum.reverse(acc)

  defp sanitize_binary(<<@escape, "[", rest::binary>>, acc) do
    case take_csi(rest, "") do
      {:sgr, sequence, rest} -> sanitize_binary(rest, [sequence | acc])
      {:drop, rest} -> sanitize_binary(rest, acc)
    end
  end

  defp sanitize_binary(<<@escape, "]", rest::binary>>, acc) do
    sanitize_binary(drop_osc(rest), acc)
  end

  defp sanitize_binary(<<@escape, "P", rest::binary>>, acc) do
    sanitize_binary(drop_until_st(rest), acc)
  end

  defp sanitize_binary(<<@escape, "_", rest::binary>>, acc) do
    sanitize_binary(drop_until_st(rest), acc)
  end

  defp sanitize_binary(<<@escape, "^", rest::binary>>, acc) do
    sanitize_binary(drop_until_st(rest), acc)
  end

  defp sanitize_binary(<<@escape, _code, rest::binary>>, acc) do
    sanitize_binary(rest, acc)
  end

  defp sanitize_binary(<<"\r", rest::binary>>, acc), do: sanitize_binary(rest, ["\n" | acc])
  defp sanitize_binary(<<"\n", rest::binary>>, acc), do: sanitize_binary(rest, ["\n" | acc])
  defp sanitize_binary(<<"\t", rest::binary>>, acc), do: sanitize_binary(rest, ["    " | acc])

  defp sanitize_binary(<<char, rest::binary>>, acc) when char < 0x20,
    do: sanitize_binary(rest, acc)

  defp sanitize_binary(<<char::utf8, rest::binary>>, acc),
    do: sanitize_binary(rest, [<<char::utf8>> | acc])

  defp sanitize_binary(<<_byte, rest::binary>>, acc), do: sanitize_binary(rest, acc)

  defp take_csi(<<final, rest::binary>>, params) when final in 0x40..0x7E do
    sequence = <<@escape, "[", params::binary, final>>

    if final == ?m do
      {:sgr, sequence, rest}
    else
      {:drop, rest}
    end
  end

  defp take_csi(<<char, rest::binary>>, params), do: take_csi(rest, <<params::binary, char>>)
  defp take_csi(<<>>, _params), do: {:drop, ""}

  defp drop_osc(binary), do: drop_osc(binary, binary)

  defp drop_osc(<<@bell, rest::binary>>, _original), do: rest
  defp drop_osc(<<@escape, "\\", rest::binary>>, _original), do: rest
  defp drop_osc(<<_char, rest::binary>>, original), do: drop_osc(rest, original)
  defp drop_osc(<<>>, _original), do: ""

  defp drop_until_st(<<@escape, "\\", rest::binary>>), do: rest
  defp drop_until_st(<<_char, rest::binary>>), do: drop_until_st(rest)
  defp drop_until_st(<<>>), do: ""
end
