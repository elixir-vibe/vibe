defmodule Exy.TUI.Widgets.Footer do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    usage = Map.get(props, :usage, %{}) || %{}
    tokens = Map.get(usage, :total_tokens, 0)
    separator = Theme.symbol(theme, :separator)
    left = [short_cwd(Map.get(props, :cwd)), separator, Map.get(props, :session_id)]

    right = [
      to_string(Map.get(props, :model)),
      separator,
      to_string(Map.get(props, :status)),
      separator,
      to_string(tokens),
      " tok"
    ]

    [Theme.fg(theme, :dim, Widget.join_sides(left, right, width))]
  end

  defp short_cwd(nil), do: ""

  defp short_cwd(cwd) do
    home = System.user_home!()

    if String.starts_with?(cwd, home), do: "~" <> String.replace_prefix(cwd, home, ""), else: cwd
  end
end
