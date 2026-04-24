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
    subscription = Map.get(props, :subscription)
    separator = Theme.symbol(theme, :separator)

    model_part = [
      Theme.fg(theme, :accent, Theme.symbol(theme, :model_icon)),
      " ",
      Theme.bold(model)
    ]

    provider_part = if provider, do: Theme.fg(theme, :dim, [" via ", provider]), else: ""

    right =
      [
        reasoning,
        subscription,
        context_label(percent),
        if(tokens != "0", do: tokens),
        if(cost, do: ["$", :erlang.float_to_binary(cost * 1.0, decimals: 3)])
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.intersperse(separator)
      |> then(&Theme.fg(theme, context_color(percent), &1))

    [Widget.join_sides([model_part, provider_part], right, width)]
  end

  defp context_label(nil), do: nil
  defp context_label(percent), do: [context_icon(percent), " ", format_percent(percent)]

  defp context_icon(percent) when percent >= 85, do: "ctx!"
  defp context_icon(_percent), do: "ctx"

  defp context_color(percent) when is_number(percent) and percent >= 85, do: :warning
  defp context_color(_percent), do: :muted

  defp format_tokens(nil), do: "0"
  defp format_tokens(count) when count < 1_000, do: to_string(count)
  defp format_tokens(count) when count < 1_000_000, do: "#{Float.round(count / 1_000, 1)}K"
  defp format_tokens(count), do: "#{Float.round(count / 1_000_000, 1)}M"

  defp format_percent(percent) when is_float(percent), do: "#{Float.round(percent, 1)}%"
  defp format_percent(percent), do: "#{percent}%"
end
