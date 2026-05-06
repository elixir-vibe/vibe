defmodule Vibe.TUI.RenderTree do
  @moduledoc "Semantic TUI render tree with stable component identities."

  defstruct nodes: []

  @type tree_node :: %__MODULE__.Node{}
  @type t :: %__MODULE__{nodes: [tree_node()]}

  defmodule Node do
    @moduledoc "A semantic render tree node."

    defstruct [:id, :component, cache?: true]

    @type t :: %__MODULE__{id: term(), component: term(), cache?: boolean()}
  end

  @spec new([tree_node()]) :: t()
  def new(nodes \\ []) when is_list(nodes), do: %__MODULE__{nodes: nodes}

  @spec node(term(), term(), keyword()) :: tree_node()
  def node(id, component, opts \\ []) do
    %Node{id: id, component: component, cache?: Keyword.get(opts, :cache?, true)}
  end
end
