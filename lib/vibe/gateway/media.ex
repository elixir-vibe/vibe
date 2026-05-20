defmodule Vibe.Gateway.Media do
  @moduledoc "Normalized media attachment metadata from an external chat gateway."

  defstruct [:path, :mime_type, :filename]

  @type t :: %__MODULE__{
          path: Path.t(),
          mime_type: String.t() | nil,
          filename: String.t() | nil
        }
end
