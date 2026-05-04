defmodule Exy.Command.Result do
  @moduledoc "Structured result from a supervised command execution."
  @enforce_keys [:id, :argv, :cwd, :status, :output, :output_path, :duration_ms]
  defstruct [:id, :argv, :cwd, :status, :exit_status, :output, :output_path, :duration_ms]

  @type status :: :ok | :error | :timeout | :cancelled | :running

  @type t :: %__MODULE__{
          id: String.t(),
          argv: [String.t()],
          cwd: Path.t(),
          status: status(),
          exit_status: non_neg_integer() | nil,
          output: String.t(),
          output_path: Path.t(),
          duration_ms: non_neg_integer()
        }
end
