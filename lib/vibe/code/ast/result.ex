defmodule Vibe.Code.AST.Result do
  @moduledoc "Structured AST operation result."
  @derive Jason.Encoder
  @type t :: %__MODULE__{
          action: Vibe.Code.AST.action(),
          path: String.t() | nil,
          pattern: term(),
          replacement: term(),
          dry_run: boolean() | nil,
          result: term(),
          diff: term()
        }

  defstruct action: nil,
            path: nil,
            pattern: nil,
            replacement: nil,
            dry_run: nil,
            result: nil,
            diff: nil
end
