defmodule Exy.Skill.Executable do
  @moduledoc false

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t(),
          module: module(),
          metadata: map(),
          markdown: String.t(),
          apis: [Exy.Plugin.API.t()]
        }

  @enforce_keys [:name, :path, :module]
  defstruct [:name, :path, :module, metadata: %{}, markdown: "", apis: []]
end
