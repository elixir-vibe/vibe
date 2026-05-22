defmodule Vibe.TUI.Widgets.ModelInfo.Parts do
  @moduledoc false

  alias Vibe.Terminal.Theme

  @thousand_tokens 1_000
  @million_tokens 1_000_000

  @spec model(map(), map()) :: iodata()
  def model(props, theme) do
    model = Map.get(props, :model, "no-model")
    provider = Map.get(props, :provider)

    [
      [Theme.fg(theme, :accent, Theme.symbol(theme, :model_icon)), " ", Theme.bold(model)],
      if(provider, do: Theme.fg(theme, :dim, [" via ", provider]), else: "")
    ]
  end

  @spec status(map(), map()) :: iodata()
  def status(props, theme) do
    usage = Map.get(props, :usage, %{}) || %{}
    tokens = format_tokens(Map.get(usage, :total_tokens, 0))
    percent = Map.get(props, :context_percent)
    cost = Map.get(usage, :total_cost)

    [
      Map.get(props, :effort) || Map.get(props, :reasoning),
      Map.get(props, :subscription),
      context_label(percent),
      if(tokens != "0", do: tokens),
      if(cost, do: ["$", :erlang.float_to_binary(cost * 1.0, decimals: 3)])
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.intersperse(Theme.symbol(theme, :separator))
    |> then(&Theme.fg(theme, context_color(percent), &1))
  end

  defp context_label(nil), do: nil
  defp context_label(percent), do: [context_icon(percent), " ", format_percent(percent)]

  defp context_icon(percent) when percent >= 85, do: "ctx!"
  defp context_icon(_percent), do: "ctx"

  defp context_color(percent) when is_number(percent) and percent >= 85, do: :warning
  defp context_color(_percent), do: :muted

  defp format_tokens(nil), do: "0"
  defp format_tokens(count) when count < @thousand_tokens, do: to_string(count)

  defp format_tokens(count) when count < @million_tokens,
    do: "#{Float.round(count / @thousand_tokens, 1)}K"

  defp format_tokens(count), do: "#{Float.round(count / @million_tokens, 1)}M"

  defp format_percent(percent) when is_float(percent), do: "#{Float.round(percent, 1)}%"
  defp format_percent(percent), do: "#{percent}%"
end
