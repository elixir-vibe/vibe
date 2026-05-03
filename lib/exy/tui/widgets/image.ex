defmodule Exy.TUI.Widgets.Image do
  @moduledoc "TUI widget for inline terminal images with text fallback."
  @behaviour Exy.TUI.Widget

  alias Exy.TUI.{Image, Theme, Widget}

  defstruct [:image, max_width_cells: 80]

  @type t :: %__MODULE__{image: Exy.Model.Content.Image.t(), max_width_cells: pos_integer()}

  @spec new(Exy.Model.Content.Image.t(), keyword()) :: t()
  def new(%Exy.Model.Content.Image{} = image, opts \\ []) do
    %__MODULE__{image: image, max_width_cells: Keyword.get(opts, :max_width_cells, 80)}
  end

  @impl true
  def render(%Exy.TUI.Node{props: props}, width, theme) do
    props
    |> Map.fetch!(:image)
    |> new(max_width_cells: Map.get(props, :max_width_cells, 80))
    |> render(width, theme)
  end

  def render(%__MODULE__{} = widget, width, theme) do
    width = min(width, widget.max_width_cells)

    case Image.capabilities().images do
      :kitty ->
        rows = Image.rows(widget.image.width, widget.image.height, width)

        sequence =
          Image.kitty(widget.image.data,
            columns: width,
            rows: rows,
            image_id: :erlang.phash2(widget.image.data)
          )

        [sequence | List.duplicate("", max(rows - 1, 0))]

      :iterm2 ->
        rows = Image.rows(widget.image.width, widget.image.height, width)

        sequence =
          Image.iterm2(widget.image.data,
            width: "#{width}ch",
            height: "#{rows}ch",
            name: widget.image.filename
          )

        [sequence | List.duplicate("", max(rows - 1, 0))]

      nil ->
        [[Theme.fg(theme, :muted, Image.fallback(widget.image))] |> Widget.pad_line(width)]
    end
  end
end
