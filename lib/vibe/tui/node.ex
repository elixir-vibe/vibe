defmodule Vibe.TUI.Node do
  @moduledoc """
  Declarative TUI node data.
  """

  defstruct [:type, props: %{}, children: []]

  @type t :: %__MODULE__{}
end
