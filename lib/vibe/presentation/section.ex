defmodule Vibe.Presentation.Section do
  @moduledoc "Renderer-neutral semantic UI document section."

  alias Vibe.Presentation.Widget

  @type t :: %__MODULE__{
          id: atom() | String.t(),
          title: String.t(),
          description: String.t() | nil,
          widgets: [Widget.t()],
          metadata: map()
        }

  @enforce_keys [:id, :title]
  defstruct [:id, :title, description: nil, widgets: [], metadata: %{}]

  @spec new(t() | keyword() | map()) :: t()
  def new(%__MODULE__{} = section), do: normalize_widgets(section)
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(%{id: id, title: title} = attrs) do
    %__MODULE__{
      id: id,
      title: title,
      description: Map.get(attrs, :description),
      widgets: Map.get(attrs, :widgets, Map.get(attrs, :blocks, [])),
      metadata: Map.get(attrs, :metadata, %{})
    }
    |> normalize_widgets()
  end

  defp normalize_widgets(%__MODULE__{} = section) do
    %{section | widgets: Enum.map(section.widgets, &normalize_widget/1)}
  end

  defp normalize_widget(%Widget{} = widget), do: widget
  defp normalize_widget({:markdown, text, opts}), do: Widget.markdown(widget_id(opts), text, opts)
  defp normalize_widget({:text, text, opts}), do: Widget.lines(widget_id(opts), text, opts)

  defp normalize_widget({:inspect, value, opts}),
    do: Widget.lines(widget_id(opts), inspect(value, pretty: true, limit: 40), opts)

  defp normalize_widget(%{id: _id, type: _type} = widget), do: Widget.normalize(widget)

  defp normalize_widget(value),
    do: Widget.lines(:inspect, inspect(value, pretty: true, limit: 40))

  defp widget_id(opts), do: Keyword.get(opts, :id, :content)
end
