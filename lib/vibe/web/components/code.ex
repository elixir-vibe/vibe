defmodule Vibe.Web.Components.Code do
  @moduledoc "Markdown, source, diff, and text rendering helpers for Vibe Web components."

  @spec markdown_html(String.t() | nil) :: String.t()
  def markdown_html(text) do
    MDEx.to_html!(text || "",
      extension: [table: true, strikethrough: true, tasklist: true, autolink: true],
      render: [unsafe: false]
    )
  end

  @spec source_html(String.t(), String.t()) :: IO.chardata()
  def source_html(text, language) do
    {:ok, html} =
      Lumis.highlight(text,
        formatter: {:html_inline, language: language, pre_class: "m-0 !bg-transparent !p-0"}
      )

    html
  rescue
    _error -> ["<pre><code>", html_escape(text), "</code></pre>"]
  end

  @spec summary_html(String.t()) :: IO.chardata()
  def summary_html(code) do
    {:ok, html} =
      Lumis.highlight(code,
        formatter:
          {:html_inline, language: "elixir", pre_class: "m-0 !bg-transparent !p-0 opacity-70"}
      )

    html
  rescue
    _error -> html_escape(code)
  end

  @spec diff_html(String.t()) :: IO.chardata()
  def diff_html(text) do
    rows =
      text
      |> String.split("\n")
      |> Enum.map(fn line ->
        class =
          cond do
            String.starts_with?(line, "+") -> "text-vibe-success bg-vibe-success/10"
            String.starts_with?(line, "-") -> "text-vibe-error bg-vibe-error/10"
            true -> "text-vibe-fg"
          end

        [
          "<div class=\"font-mono text-xs leading-5 whitespace-pre ",
          class,
          "\">",
          html_escape(line),
          "</div>"
        ]
      end)

    ["<pre class=\"m-0 overflow-auto bg-transparent p-0\"><code>", rows, "</code></pre>"]
  end

  @spec display_text(term()) :: String.t() | nil
  def display_text(nil), do: nil

  def display_text(value) do
    value
    |> IO.iodata_to_binary()
    |> strip_ansi()
  rescue
    Protocol.UndefinedError -> inspect(value, pretty: true, limit: 20)
    ArgumentError -> inspect(value, pretty: true, limit: 20)
  end

  @spec html_escape(term()) :: String.t()
  def html_escape(value) do
    value
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  @spec strip_ansi(String.t()) :: String.t()
  def strip_ansi(text) do
    Regex.replace(~r/\e\[[0-9;?]*[ -\/]*[@-~]/, text, "")
  end
end
