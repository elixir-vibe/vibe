defmodule Vibe.Remote.Transport.Distribution do
  @moduledoc """
  Trusted remote transport backed by Erlang distribution.

  This transport is intentionally BEAM-native: callers get a connected node and
  can use `:rpc`, `:erpc`, remote PIDs, and node monitoring. That makes it useful
  for local server mode, tests, and trusted internal nodes, but it should not be
  treated as the public/user-facing remote protocol.
  """

  @behaviour Vibe.Remote.Transport

  alias Vibe.Server.{Cookie, Metadata}

  @impl true
  def connect(:metadata, _opts), do: connect()
  def connect(node, _opts) when is_atom(node), do: connect_node(node)

  def connect(node, opts) when is_binary(node),
    do: node |> :erlang.binary_to_atom() |> connect(opts)

  @spec connect() :: {:ok, node()} | {:error, term()}
  def connect do
    with {:ok, %{"node" => node_name} = metadata} <- Metadata.read(),
         :ok <- verify_build(metadata),
         :ok <- check_tls_compatibility(metadata),
         {:ok, node} <- parse_node(node_name),
         {:ok, node} <- connect_node(node) do
      {:ok, node}
    end
  end

  @spec connect_node(node()) :: {:ok, node()} | {:error, term()}
  def connect_node(node) do
    with :ok <- ensure_distribution(),
         true <- Node.connect(node) do
      {:ok, node}
    else
      false -> {:error, :not_connected}
      error -> error
    end
  end

  @spec ensure_distribution() :: :ok | {:error, term()}
  def ensure_distribution do
    cookie = Cookie.get()

    if Node.alive?() do
      :ok
    else
      name =
        :erlang.binary_to_atom(
          "vibe_client_#{System.unique_integer([:positive, :monotonic])}_#{System.os_time(:nanosecond)}@127.0.0.1"
        )

      ensure_epmd()

      case Node.start(name) do
        {:ok, _pid} -> :ok
        {:error, {:already_started, _pid}} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
    |> case do
      :ok ->
        Node.set_cookie(cookie)
        :ok

      error ->
        error
    end
  end

  defp verify_build(%{"build_id" => build_id} = metadata) when is_binary(build_id) do
    if build_id == Vibe.Build.id(), do: :ok, else: {:error, {:stale_server, metadata}}
  end

  defp verify_build(metadata), do: {:error, {:stale_server, metadata}}

  defp check_tls_compatibility(%{"tls" => true}) do
    if tls_distribution?() do
      :ok
    else
      require Logger

      Logger.warning(
        "Server uses TLS distribution but this client does not. " <>
          "Set ERL_FLAGS='-proto_dist inet_tls -ssl_dist_optfile #{Vibe.Server.TLS.dist_config_path()}' " <>
          "before starting mix/vibe."
      )

      {:error, :tls_mismatch}
    end
  end

  defp check_tls_compatibility(_metadata), do: :ok

  defp tls_distribution? do
    case :net_kernel.get_state() do
      %{started: :no} -> false
      _ -> :inet_tls_dist in (:net_kernel.get_state() |> Map.get(:protos, []))
    end
  rescue
    _error -> false
  end

  defp parse_node(node_name) when is_binary(node_name),
    do: {:ok, :erlang.binary_to_atom(node_name)}

  defp ensure_epmd, do: System.cmd("epmd", ["-daemon"])
end
