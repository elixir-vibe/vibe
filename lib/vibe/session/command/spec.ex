defmodule Vibe.Session.Command.Spec do
  @moduledoc "Slash command metadata contract."

  defstruct [:name, :description, aliases: [], selectors: []]

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          aliases: [String.t()],
          selectors: [atom()]
        }
end
