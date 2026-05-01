defmodule Exy.Code.AST.Result do
  @moduledoc "Internal implementation module."
  @derive Jason.Encoder
  defstruct action: nil,
            path: nil,
            pattern: nil,
            replacement: nil,
            dry_run: nil,
            result: nil,
            diff: nil
end
