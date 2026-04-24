defmodule Exy.TUI.Node do
  @moduledoc """
  Declarative TUI node data.
  """

  defstruct [:type, props: %{}, children: []]

  @type t :: %__MODULE__{type: atom(), props: map(), children: [t() | IO.chardata()]}
end
