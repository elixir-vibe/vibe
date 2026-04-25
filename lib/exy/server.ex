defmodule Exy.Server do
  @moduledoc false

  alias Exy.Server.{Cookie, Metadata}

  @spec start(keyword()) :: :ok | {:error, term()}
  def start(opts \\ []) do
    name = Keyword.get_lazy(opts, :name, &default_node_name/0)

    with {:ok, _apps} <- Application.ensure_all_started(:exy),
         :ok <- ensure_distribution(name),
         :ok <- write_metadata(name) do
      if Keyword.get(opts, :foreground, false) do
        Process.sleep(:infinity)
      end

      :ok
    end
  end

  @spec status() :: {:ok, map()} | {:error, term()}
  def status, do: Metadata.read()

  @spec stop() :: :ok | {:error, term()}
  def stop do
    with {:ok, %{"node" => node_name}} <- Metadata.read(),
         {:ok, node} <- parse_node(node_name),
         :ok <- ensure_client_distribution(),
         true <- connect_node(node) do
      _ = :rpc.call(node, :init, :stop, [])
      Metadata.delete()
      :ok
    else
      false -> {:error, :not_connected}
      error -> error
    end
  end

  defp ensure_distribution(name) do
    cookie = Cookie.get()

    ensure_epmd()

    case Node.start(name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, {{:already_started, _pid}, _child}} -> :ok
      {:error, reason} -> {:error, reason}
    end
    |> case do
      :ok ->
        Node.set_cookie(cookie)
        :ok

      error ->
        error
    end
  end

  defp write_metadata(name) do
    Metadata.write!(%{
      node: Atom.to_string(name),
      cookie_path: Cookie.path(),
      pid: System.pid(),
      version: version(),
      started_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  defp default_node_name do
    user = System.get_env("USER") || "user"
    String.to_atom("exy_server_#{user}@127.0.0.1")
  end

  defp version, do: :exy |> Application.spec(:vsn) |> to_string()

  defp ensure_client_distribution do
    if Node.alive?() do
      :ok
    else
      ensure_distribution(
        String.to_atom("exy_stop_#{System.unique_integer([:positive])}@127.0.0.1")
      )
    end
  end

  defp parse_node(node_name) when is_binary(node_name), do: {:ok, String.to_atom(node_name)}
  defp connect_node(node), do: Node.connect(node)
  defp ensure_epmd, do: System.cmd("epmd", ["-daemon"])
end
