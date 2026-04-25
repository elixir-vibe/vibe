defmodule Exy.TUI.Widgets.PluginWidget do
  @moduledoc false

  @behaviour Exy.TUI.Widget

  alias Exy.TUI.Widget

  @impl true
  def render(%{props: %{type: :progress, props: props}}, width, _theme) do
    title = Map.get(props, :title, "Progress")
    current = Map.get(props, :current, 0)
    total = Map.get(props, :total, 0)
    message = Map.get(props, :message)
    label = if total in [nil, 0], do: "#{current}", else: "#{current}/#{total}"

    [title, label, message]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" • ")
    |> Widget.fit_line(width)
    |> List.wrap()
  end

  def render(%{props: %{props: props}}, width, _theme) do
    props
    |> Map.get(:content, [])
    |> List.wrap()
    |> Enum.map(&Widget.fit_line(&1, width))
  end
end
