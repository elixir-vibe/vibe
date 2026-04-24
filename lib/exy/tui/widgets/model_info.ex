defmodule Exy.TUI.Widgets.ModelInfo do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Theme, Widget}

  @impl true
  def render(%{props: props}, width, theme) do
    model = Map.get(props, :model, "no-model")
    provider = Map.get(props, :provider)
    reasoning = Map.get(props, :reasoning)
    usage = Map.get(props, :usage, %{}) || %{}
    tokens = format_tokens(Map.get(usage, :total_tokens, 0))
    percent = Map.get(props, :context_percent)
    cost = Map.get(usage, :total_cost)

    separator = Theme.symbol(theme, :separator)

    right = [
      if(provider, do: [" via ", provider], else: ""),
      if(reasoning, do: [separator, reasoning], else: "")
    ]

    meta = [
      if(percent, do: [separator, format_percent(percent)], else: ""),
      if(tokens != "0", do: [separator, tokens], else: ""),
      if(cost, do: [separator, "$", :erlang.float_to_binary(cost * 1.0, decimals: 3)], else: "")
    ]

    [
      Widget.fit_line(
        [
          Theme.fg(theme, :accent, Theme.symbol(theme, :model_icon)),
          " ",
          Theme.bold(model),
          Theme.fg(theme, :dim, right),
          Theme.fg(theme, :muted, meta)
        ],
        width
      )
    ]
  end

  defp format_tokens(nil), do: "0"
  defp format_tokens(count) when count < 1_000, do: to_string(count)
  defp format_tokens(count) when count < 1_000_000, do: "#{Float.round(count / 1_000, 1)}K"
  defp format_tokens(count), do: "#{Float.round(count / 1_000_000, 1)}M"

  defp format_percent(percent) when is_float(percent), do: "#{Float.round(percent, 1)}%"
  defp format_percent(percent), do: "#{percent}%"
end
