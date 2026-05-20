defmodule Vibe.Remote do
  @moduledoc """
  Remote Vibe connection facade.

  The existing implementation is the trusted Erlang distribution transport. It is
  kept for local server mode and internal/trusted BEAM nodes while user-facing
  remote access can grow as a separate transport.
  """

  alias Vibe.Remote.Transport.{Distribution, SSH}

  @type transport :: :distribution | :ssh

  @spec connect(keyword()) :: {:ok, node() | SSH.t()} | {:error, term()}
  def connect(opts \\ []) do
    case Keyword.get(opts, :transport, :distribution) do
      :distribution -> Distribution.connect()
      :ssh -> SSH.connect(nil, opts)
      transport -> {:error, {:unsupported_transport, transport}}
    end
  end

  @spec connect_node(node() | String.t() | {String.t(), non_neg_integer()}, keyword()) ::
          {:ok, node() | SSH.t()} | {:error, term()}
  def connect_node(node, opts \\ []) do
    case Keyword.get(opts, :transport, :distribution) do
      :distribution -> Distribution.connect(node, opts)
      :ssh -> SSH.connect(node, opts)
      transport -> {:error, {:unsupported_transport, transport}}
    end
  end
end
