defmodule Vibe.Tool.PluginResult do
  @moduledoc "Tool-result payload passed to plugin tool_result callbacks."

  @enforce_keys [:name, :result, :raw_result]
  defstruct [:name, :result, :raw_result]

  @type t :: %__MODULE__{name: atom(), result: term(), raw_result: term()}

  @spec new(atom(), term(), term()) :: t()
  def new(name, result, raw_result) when is_atom(name) do
    %__MODULE__{name: name, result: result, raw_result: raw_result}
  end
end
