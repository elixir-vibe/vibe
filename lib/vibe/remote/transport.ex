defmodule Vibe.Remote.Transport do
  @moduledoc """
  Behaviour for remote Vibe transports.

  Transports own the network/authentication boundary. Higher-level modules should
  expose Vibe session and subagent operations instead of leaking transport-specific
  primitives to callers.
  """

  @type target :: term()
  @type connection :: term()

  @callback connect(target(), keyword()) :: {:ok, connection()} | {:error, term()}
end
