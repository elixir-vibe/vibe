defmodule Vibe.Sandbox.Policy do
  @moduledoc """
  Declarative isolation policy for Vibe evaluation runtimes.

  OTP gives strong fault isolation, supervision, timeouts, monitors, group leaders,
  ports, and separate BEAM nodes/processes. It is not, by itself, a security
  sandbox for malicious code with filesystem/network access.
  """

  @default_timeout_ms 30_000

  @type isolation :: :same_process | :process | :node | :os_process | :container | :remote

  @type t :: %__MODULE__{
          isolation: isolation(),
          timeout: pos_integer(),
          max_heap_size: pos_integer() | nil,
          cwd: Path.t() | nil,
          env: %{optional(String.t()) => String.t()},
          network: :inherit | :off,
          filesystem: :inherit | :workspace | :tmp | :readonly
        }

  defstruct isolation: :os_process,
            timeout: @default_timeout_ms,
            max_heap_size: nil,
            cwd: nil,
            env: %{},
            network: :inherit,
            filesystem: :inherit

  @spec new(keyword() | map()) :: t()
  def new(opts \\ []) do
    opts = if is_map(opts), do: Map.to_list(opts), else: opts
    struct!(__MODULE__, opts)
  end
end
