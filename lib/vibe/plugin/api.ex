defmodule Vibe.Plugin.API do
  @moduledoc """
  Describes an Elixir API exposed by a plugin for stateful eval sessions.
  """

  @type t :: %__MODULE__{
          name: atom(),
          module: module(),
          alias: atom(),
          description: String.t(),
          examples: [String.t()]
        }

  @enforce_keys [:name, :module]
  defstruct [:name, :module, :alias, description: "", examples: []]

  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(%{name: name, module: module} = attrs) when is_atom(name) and is_atom(module) do
    %__MODULE__{
      name: name,
      module: module,
      alias: Map.get(attrs, :alias) || default_alias(module),
      description: Map.get(attrs, :description, ""),
      examples: Map.get(attrs, :examples, [])
    }
  end

  defp default_alias(module) do
    module
    |> Module.split()
    |> Enum.reject(&(&1 in ["Vibe", "Plugins", "API"]))
    |> List.last()
    |> :erlang.binary_to_atom()
  end
end
