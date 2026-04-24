defmodule Exy.UI.Command do
  @moduledoc """
  UI-neutral command dispatched by TUI or LiveView clients.
  """

  @enforce_keys [:type, :data]
  defstruct [:type, :data]

  @type t :: %__MODULE__{type: atom(), data: map()}

  @spec new(atom(), map()) :: t()
  def new(type, data \\ %{}) when is_atom(type) and is_map(data),
    do: %__MODULE__{type: type, data: data}
end
