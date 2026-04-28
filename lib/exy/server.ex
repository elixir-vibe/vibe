defmodule Exy.Server do
  @moduledoc false

  alias Exy.Server.{Cookie, Metadata}

  @remote_stop_timeout_ms 5_000
  @server_command_marker "exy server start --foreground"

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
  def status do
    case Metadata.read() do
      {:ok, %{"node" => node_name} = metadata} ->
        with {:ok, node} <- parse_node(node_name),
             :ok <- ensure_client_distribution() do
          running? = Node.connect(node)
          {:ok, Map.put(metadata, "running", running?)}
        end

      {:error, :enoent} ->
        {:ok, %{running: false, metadata_path: Metadata.path(), reason: :not_started}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec stop() :: :ok | {:error, term()}
  def stop do
    metadata = Metadata.read()
    node = server_node(metadata)
    pid = server_os_pid(metadata)

    result = stop_node(node)
    cleanup_orphan_process(pid)
    result
  end

  @spec cleanup_metadata() :: :ok
  def cleanup_metadata do
    Metadata.delete()
  end

  @spec cleanup_orphan_processes() :: :ok
  def cleanup_orphan_processes do
    Metadata.read()
    |> server_os_pid()
    |> cleanup_orphan_process()
  end

  defp ensure_distribution(name) do
    cookie = Cookie.get()

    result =
      cond do
        Node.alive?() and Node.self() == name ->
          :ok

        Node.alive?() ->
          {:error, {:already_started_as, Node.self()}}

        true ->
          ensure_epmd()
          start_distribution(name)
      end

    case result do
      :ok ->
        Node.set_cookie(cookie)
        :ok

      error ->
        error
    end
  end

  defp start_distribution(name) do
    case Node.start(name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> distribution_already_started(name)
      {:error, {{:already_started, _pid}, _child}} -> distribution_already_started(name)
      {:error, reason} -> {:error, reason}
    end
  end

  defp distribution_already_started(name) do
    if Node.self() == name, do: :ok, else: {:error, {:already_started_as, Node.self()}}
  end

  defp write_metadata(name) do
    Metadata.write!(%{
      node: Atom.to_string(name),
      cookie_path: Cookie.path(),
      pid: System.pid(),
      version: Exy.Build.version(),
      build_id: Exy.Build.id(),
      started_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @spec default_node_name() :: node()
  def default_node_name do
    user = System.get_env("USER") || "user"

    home_hash =
      :sha256
      |> :crypto.hash(Exy.Paths.home())
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    String.to_atom("exy_server_#{user}_#{home_hash}@127.0.0.1")
  end

  defp stop_node(node) do
    with :ok <- ensure_client_distribution(),
         true <- connect_node(node) do
      stop_connected_node(node)
      cleanup_metadata()
      :ok
    else
      false ->
        cleanup_metadata()
        {:error, :not_connected}

      error ->
        error
    end
  end

  defp stop_connected_node(node) do
    Node.monitor(node, true)

    try do
      _ = :erpc.call(node, :init, :stop, [], @remote_stop_timeout_ms)
      wait_for_nodedown(node, @remote_stop_timeout_ms)
    catch
      :exit, _reason -> :ok
      _kind, _reason -> :ok
    after
      Node.monitor(node, false)
      flush_nodedown(node)
    end
  end

  defp wait_for_nodedown(node, timeout_ms) do
    receive do
      {:nodedown, ^node} -> :ok
    after
      timeout_ms -> :timeout
    end
  end

  defp flush_nodedown(node) do
    receive do
      {:nodedown, ^node} -> :ok
    after
      0 -> :ok
    end
  end

  defp ensure_client_distribution do
    if Node.alive?() do
      :ok
    else
      ensure_distribution(
        String.to_atom(
          "exy_stop_#{System.unique_integer([:positive, :monotonic])}_#{System.os_time(:nanosecond)}@127.0.0.1"
        )
      )
    end
  end

  defp server_node({:ok, %{"node" => node_name}}) when is_binary(node_name),
    do: String.to_atom(node_name)

  defp server_node(_metadata), do: default_node_name()

  defp server_os_pid({:ok, %{"pid" => pid}}) when is_binary(pid), do: pid
  defp server_os_pid(_metadata), do: nil

  defp cleanup_orphan_process(nil), do: :ok

  defp cleanup_orphan_process(pid) do
    cond do
      pid == System.pid() -> :ok
      server_os_process?(pid) -> terminate_os_process(pid)
      true -> :ok
    end
  end

  defp server_os_process?(pid) do
    case System.cmd("ps", ["-p", pid, "-o", "command="], stderr_to_stdout: true) do
      {command, 0} -> String.contains?(command, @server_command_marker)
      {_output, _status} -> false
    end
  rescue
    _error -> false
  end

  defp terminate_os_process(pid) do
    _ = System.cmd("kill", [pid], stderr_to_stdout: true)
    :ok
  rescue
    _error -> :ok
  end

  defp parse_node(node_name) when is_binary(node_name), do: {:ok, String.to_atom(node_name)}
  defp connect_node(node), do: Node.connect(node)
  defp ensure_epmd, do: System.cmd("epmd", ["-daemon"])
end
