defmodule Vibe.Presentation.Widget do
  @moduledoc "Renderer-neutral presentation widget shared by TUI and web surfaces."

  @placements [:above_editor, :below_editor, :sidebar]
  @types [:lines, :markdown, :status, :panel, :progress, :list]

  @type placement :: :above_editor | :below_editor | :sidebar
  @type widget_type :: :lines | :markdown | :status | :panel | :progress | :list

  @type t :: %__MODULE__{
          id: String.t(),
          type: widget_type(),
          placement: placement(),
          props: map(),
          version: non_neg_integer()
        }

  @enforce_keys [:id, :type]
  defstruct [:id, :type, placement: :above_editor, props: %{}, version: 0]

  @spec new(String.t() | atom(), widget_type(), map(), keyword()) :: t()
  def new(id, type, props \\ %{}, opts \\ []) when type in @types and is_map(props) do
    placement = opts |> Keyword.get(:placement, :above_editor) |> normalize_placement()

    unless placement in @placements do
      raise ArgumentError, "invalid widget placement: #{inspect(placement)}"
    end

    %__MODULE__{
      id: normalize_id(id),
      type: type,
      placement: placement,
      props: props,
      version: Keyword.get(opts, :version, 0)
    }
  end

  @spec lines(String.t() | atom(), [String.t()] | String.t(), keyword()) :: t()
  def lines(id, content, opts \\ []) do
    new(id, :lines, %{content: List.wrap(content)}, opts)
  end

  @spec markdown(String.t() | atom(), String.t(), keyword()) :: t()
  def markdown(id, content, opts \\ []) when is_binary(content) do
    new(id, :markdown, %{content: content}, opts)
  end

  @spec progress(String.t() | atom(), keyword()) :: t()
  def progress(id, opts) do
    props =
      opts
      |> Keyword.take([:title, :current, :total, :message])
      |> Map.new()

    new(id, :progress, props, Keyword.take(opts, [:placement, :version]))
  end

  @spec normalize(t() | map()) :: t()
  def normalize(%__MODULE__{} = widget), do: widget

  def normalize(%{id: id, type: type} = widget) do
    new(normalize_id(id), normalize_type(type), Map.get(widget, :props, %{}),
      placement: Map.get(widget, :placement, :above_editor),
      version: Map.get(widget, :version, 0)
    )
  end

  defp normalize_type(type) when is_binary(type) do
    case Enum.find(@types, &(Atom.to_string(&1) == type)) do
      nil -> type
      atom -> atom
    end
  end

  defp normalize_type(type), do: type

  defp normalize_placement(placement) when is_binary(placement) do
    case Enum.find(@placements, &(Atom.to_string(&1) == placement)) do
      nil -> placement
      atom -> atom
    end
  end

  defp normalize_placement(placement), do: placement

  defp normalize_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_id(id) when is_binary(id), do: id
end
