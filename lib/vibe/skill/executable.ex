defmodule Vibe.Skill.Executable do
  @moduledoc "Trusted executable Elixir skill evaluation."

  alias Vibe.Plugin.API

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t(),
          module: module(),
          metadata: map(),
          markdown: String.t(),
          apis: [API.t()]
        }

  @enforce_keys [:name, :path, :module]
  defstruct [:name, :path, :module, metadata: %{}, markdown: "", apis: []]
end
