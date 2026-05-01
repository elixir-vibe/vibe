defmodule Exy.Command.Job do
  @moduledoc "Internal implementation module."
  @enforce_keys [:id, :argv, :cwd, :pid, :output_path, :started_at]
  defstruct [:id, :argv, :cwd, :pid, :output_path, :started_at]

  @type t :: %__MODULE__{
          id: String.t(),
          argv: [String.t()],
          cwd: Path.t(),
          pid: pid(),
          output_path: Path.t(),
          started_at: DateTime.t()
        }
end
