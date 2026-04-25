defmodule Exy.Remote do
  @moduledoc false

  alias Exy.Server.{Cookie, Metadata}

  @spec connect() :: {:ok, node()} | {:error, term()}
  def connect do
    with {:ok, %{"node" => node_name}} <- Metadata.read(),
         {:ok, node} <- parse_node(node_name),
         :ok <- ensure_distribution(),
         true <- Node.connect(node) do
      {:ok, node}
    else
      false -> {:error, :not_connected}
      error -> error
    end
  end

  @spec call(atom(), list()) :: term()
  def call(function, args \\ []) when is_atom(function) and is_list(args) do
    with {:ok, node} <- connect() do
      :rpc.call(node, Exy.Server.RPC, function, args)
    end
  end

  defp ensure_distribution do
    cookie = Cookie.get()

    if Node.alive?() do
      :ok
    else
      name = String.to_atom("exy_client_#{System.unique_integer([:positive])}@#{hostname()}")

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
  defp hostname, do: :inet.gethostname() |> elem(1) |> List.to_string()
end
