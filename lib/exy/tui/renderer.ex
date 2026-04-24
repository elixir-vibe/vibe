defmodule Exy.TUI.Renderer do
  @moduledoc """
  Terminal renderer for Exy's semantic UI view model.

  This renderer is intentionally thin: semantic state lives in `Exy.UI`, while
  this module only turns blocks into terminal-safe lines.
  """

  alias Exy.TUI.Theme
  alias Exy.UI.{Block, ViewModel}

  @type line :: IO.chardata()

  @spec render(ViewModel.t(), pos_integer(), Theme.t()) :: [line()]
  def render(view, width, theme \\ Theme.default())

  def render(view, width, theme) when is_map(view) and is_integer(width) and width > 0 do
    body = Enum.flat_map(view.body, &render_block(&1, width, theme))
    footer = render_block(view.footer, width, theme)
    overlays = Enum.flat_map(view.overlays, &render_block(&1, width, theme))

    (body ++ footer ++ overlays)
    |> Enum.map(&fit_line(&1, width))
  end

  defp render_block(%Block.UserMessage{text: text}, width, theme) do
    prefix = Theme.fg(theme, :accent, "You: ")
    wrap(prefix <> Theme.fg(theme, :user_message_text, to_string(text)), width)
  end

  defp render_block(%Block.AssistantMessage{error: error}, width, theme) when is_binary(error) do
    wrap(Theme.fg(theme, :error, "Exy error: " <> error), width)
  end

  defp render_block(%Block.AssistantMessage{text: text}, width, theme) do
    prefix = Theme.fg(theme, :success, "Exy: ")
    wrap(prefix <> Theme.fg(theme, :assistant_message_text, to_string(text || "")), width)
  end

  defp render_block(%Block.ToolCall{} = tool, width, theme) do
    title = "Tool #{tool.name || tool.id} [#{tool.status || :unknown}]"

    styled_title =
      theme |> Theme.fg(:tool_title, title) |> tool_background(tool.status, theme)

    if tool.expanded? and tool.output do
      [styled_title | wrap(Theme.fg(theme, :tool_output, to_string(tool.output)), width)]
    else
      [styled_title]
    end
  end

  defp render_block(%Block.Footer{} = footer, width, theme) do
    usage = footer.usage || %{}
    tokens = Map.get(usage, :total_tokens, 0)
    left = "#{short_cwd(footer.cwd)} • #{footer.session_id}"
    right = "#{footer.model} • #{footer.status} • #{tokens} tok"
    [Theme.fg(theme, :dim, join_sides(left, right, width))]
  end

  defp render_block(%Block.Overlay{kind: kind}, width, theme) do
    [kind |> then(&"Overlay: #{&1}") |> fit_line(width) |> Theme.fg(theme, :accent)]
  end

  defp tool_background(text, status, theme) when status in [:ok, "ok"],
    do: Theme.bg(theme, :tool_success_bg, text)

  defp tool_background(text, status, theme) when status in [:error, "error"],
    do: Theme.bg(theme, :tool_error_bg, text)

  defp tool_background(text, _status, theme), do: Theme.bg(theme, :tool_pending_bg, text)

  defp wrap(text, width) do
    text
    |> String.split("\n")
    |> Enum.flat_map(&wrap_line(&1, width))
  end

  defp wrap_line("", _width), do: [""]

  defp wrap_line(line, width) do
    line
    |> String.graphemes()
    |> Enum.chunk_every(width)
    |> Enum.map(&Enum.join/1)
  end

  defp join_sides(left, right, width) do
    left = to_string(left)
    right = to_string(right)
    minimum_gap = 2

    if visible_length(left) + minimum_gap + visible_length(right) <= width do
      left <> String.duplicate(" ", width - visible_length(left) - visible_length(right)) <> right
    else
      fit_line(left <> "  " <> right, width)
    end
  end

  defp fit_line(line, width) do
    line = to_string(line)

    if visible_length(line) <= width do
      line
    else
      line
      |> Theme.strip()
      |> String.graphemes()
      |> Enum.take(width)
      |> Enum.join()
    end
  end

  defp visible_length(line), do: line |> Theme.strip() |> String.length()

  defp short_cwd(nil), do: ""

  defp short_cwd(cwd) do
    home = System.user_home!()

    if String.starts_with?(cwd, home), do: "~" <> String.replace_prefix(cwd, home, ""), else: cwd
  end
end
