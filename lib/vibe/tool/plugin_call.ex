defmodule Vibe.Tool.PluginCall do
  @moduledoc "Tool-call payload passed to plugin tool_call callbacks."

  @enforce_keys [:name, :args]
  defstruct [:name, :args]

  @type t :: %__MODULE__{name: atom(), args: map()}

  @spec new(atom(), map()) :: t()
  def new(name, args) when is_atom(name) and is_map(args), do: %__MODULE__{name: name, args: args}
end
