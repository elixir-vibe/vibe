defmodule Exy.Remote do
  @moduledoc "RPC bridge for server-mode session operations."
  alias Exy.Server.{Cookie, Metadata}

  @spec connect() :: {:ok, node()} | {:error, term()}
  def connect do
    with {:ok, %{"node" => node_name} = metadata} <- Metadata.read(),
         :ok <- verify_build(metadata),
         {:ok, node} <- parse_node(node_name),
         :ok <- ensure_distribution(),
         true <- Node.connect(node) do
      {:ok, node}
    else
      false -> {:error, :not_connected}
      error -> error
    end
  end

  defp verify_build(%{"build_id" => build_id} = metadata) when is_binary(build_id) do
    if build_id == Exy.Build.id(), do: :ok, else: {:error, {:stale_server, metadata}}
  end

  defp verify_build(metadata), do: {:error, {:stale_server, metadata}}

  defp ensure_distribution do
    cookie = Cookie.get()

    if Node.alive?() do
      :ok
    else
      name =
        String.to_atom(
          "exy_client_#{System.unique_integer([:positive, :monotonic])}_#{System.os_time(:nanosecond)}@127.0.0.1"
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

  defp parse_node(node_name) when is_binary(node_name), do: {:ok, String.to_atom(node_name)}
  defp ensure_epmd, do: System.cmd("epmd", ["-daemon"])
end
