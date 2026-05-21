defmodule Vibe.Presentation.Document do
  @moduledoc "Renderer-neutral presentation document shared by plugins and surfaces."

  alias Vibe.Presentation.Section

  @type t :: %__MODULE__{
          version: pos_integer(),
          title: String.t() | nil,
          description: String.t() | nil,
          sections: [Section.t()],
          metadata: map()
        }

  defstruct version: 1, title: nil, description: nil, sections: [], metadata: %{}

  @spec new(t() | keyword() | map() | nil) :: t()
  def new(nil), do: %__MODULE__{}
  def new(%__MODULE__{} = document), do: normalize_sections(document)
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      version: Map.get(attrs, :version, 1),
      title: Map.get(attrs, :title),
      description: Map.get(attrs, :description),
      sections: Map.get(attrs, :sections, []),
      metadata: Map.get(attrs, :metadata, %{})
    }
    |> normalize_sections()
  end

  @spec empty() :: t()
  def empty, do: %__MODULE__{}

  defp normalize_sections(%__MODULE__{} = document) do
    %{document | sections: Enum.map(document.sections, &Section.new/1)}
  end
end
