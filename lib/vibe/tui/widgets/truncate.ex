defmodule Vibe.TUI.Widgets.Truncate do
  @moduledoc "TUI widget: content truncation with expand hint."
  @behaviour Vibe.TUI.Widget

  alias Vibe.TUI.{Widget, Width}

  @impl true
  def render(%{props: props, children: [content | _]}, width, _theme) do
    suffix = Map.get(props, :suffix, "…")
    target = max(width, 1)

    cond do
      Width.visible_length(IO.iodata_to_binary(content)) <= target ->
        [Widget.fit_line(content, target)]

      Width.visible_length(suffix) >= target ->
        [Widget.fit_line(suffix, target)]

      true ->
        [
          Widget.fit_line(
            [Widget.fit_line(content, target - Width.visible_length(suffix)), suffix],
            target
          )
        ]
    end
  end

  def render(_node, _width, _theme), do: []
end
