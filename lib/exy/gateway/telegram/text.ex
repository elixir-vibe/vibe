defmodule Exy.Gateway.Telegram.Text do
  @moduledoc """
  Telegram-safe text rendering and splitting helpers.

  Telegram accepts a small HTML subset and limits messages to 4096 visible
  characters after entity parsing. These helpers prefer safety over clever
  Markdown fidelity: raw text is escaped, a small Markdown-like subset is mapped
  to Telegram HTML, and long messages are split on paragraph/line/word
  boundaries before sending.
  """

  @default_limit 4_096

  @doc "Converts plain/Markdown-like text to Telegram-safe HTML."
  @spec to_html(String.t()) :: String.t()
  def to_html(text) when is_binary(text) do
    text
    |> escape()
    |> render_code_fences()
    |> render_inline_code()
    |> render_bold()
    |> render_italic()
  end

  @doc "Splits text into chunks that fit Telegram's visible text limit."
  @spec split(String.t(), keyword()) :: [String.t()]
  def split(text, opts \\ []) when is_binary(text) do
    limit = Keyword.get(opts, :limit, @default_limit)

    text
    |> split_paragraphs(limit)
    |> Enum.flat_map(&split_lines(&1, limit))
    |> Enum.flat_map(&split_words(&1, limit))
    |> Enum.reject(&(&1 == ""))
  end

  @doc "Converts and splits text into Telegram-safe HTML chunks."
  @spec html_chunks(String.t(), keyword()) :: [String.t()]
  def html_chunks(text, opts \\ []) when is_binary(text) do
    text
    |> split(opts)
    |> Enum.map(&to_html/1)
  end

  @doc "Limits a string with an ellipsis, preserving valid grapheme boundaries."
  @spec limit(String.t(), pos_integer()) :: String.t()
  def limit(text, max_length) do
    if String.length(text) <= max_length,
      do: text,
      else: String.slice(text, 0, max_length - 1) <> "…"
  end

  defp split_paragraphs(text, limit), do: split_by(text, ~r/\n\n+/, "\n\n", limit)
  defp split_lines(text, limit), do: split_by(text, ~r/\n/, "\n", limit)

  defp split_by(text, regex, joiner, limit) do
    if String.length(text) <= limit do
      [text]
    else
      text
      |> String.split(regex)
      |> Enum.reduce([], &accumulate_chunk(&1, &2, joiner, limit))
      |> Enum.reverse()
    end
  end

  defp split_words(text, limit) do
    if String.length(text) <= limit do
      [text]
    else
      text
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reduce([], &accumulate_chunk(&1, &2, " ", limit))
      |> Enum.reverse()
      |> Enum.flat_map(&split_hard(&1, limit))
    end
  end

  defp accumulate_chunk(part, [], _joiner, _limit), do: [part]

  defp accumulate_chunk(part, [current | rest], joiner, limit) do
    candidate = current <> joiner <> part

    if String.length(candidate) <= limit do
      [candidate | rest]
    else
      [part, current | rest]
    end
  end

  defp split_hard(text, limit) do
    if String.length(text) <= limit do
      [text]
    else
      {chunk, rest} = String.split_at(text, limit)
      [chunk | split_hard(rest, limit)]
    end
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp render_code_fences(text) do
    Regex.replace(~r/```(?:\w+)?\n?([\s\S]*?)```/, text, fn _all, code ->
      "<pre>" <> code <> "</pre>"
    end)
  end

  defp render_inline_code(text), do: Regex.replace(~r/`([^`\n]+)`/, text, "<code>\\1</code>")
  defp render_bold(text), do: Regex.replace(~r/\*\*([^*\n]+)\*\*/, text, "<b>\\1</b>")
  defp render_italic(text), do: Regex.replace(~r/(?<!\*)\*([^*\n]+)\*(?!\*)/, text, "<i>\\1</i>")
end
