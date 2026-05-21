defmodule Vibe.CLI.Server do
  @moduledoc "Server subcommand dispatch: start, stop, restart, status."
  alias Vibe.CLI.Output
  alias Vibe.Server.Metadata

  @default_start_timeout_ms 20_000
  @shutdown_grace_ms 5_000
  @connect_poll_interval_ms 100

  @spec command([String.t()], keyword()) :: :ok | {:error, term()}
  def command(["start"], opts), do: command(["start", "--auto"], opts)

  def command(["start", _mode], opts) do
    if opts[:foreground] do
      Vibe.Server.start(server_start_opts(opts))
    else
      Output.print(start_background(@default_start_timeout_ms, opts), opts)
    end
  end

  def command(["status"], opts), do: Output.print(Vibe.Server.status(), opts)
  def command(["stop"], opts), do: Output.print(Vibe.Server.stop(), opts)

  def command(["restart"], opts) do
    node = current_server_node()
    _ = Vibe.Server.stop()
    wait_for_shutdown(node, @shutdown_grace_ms)

    if opts[:foreground] do
      Vibe.Server.start(server_start_opts(opts))
    else
      Output.print(start_background(@default_start_timeout_ms, opts), opts)
    end
  end

  def command(_args, _opts) do
    Output.error(
      "Usage: vibe server start [--foreground] | restart [--foreground] | status | stop"
    )

    {:error, :invalid_server_command}
  end

  @spec ensure_running(non_neg_integer(), keyword()) :: :ok | {:error, term()}
  def ensure_running(timeout_ms \\ @default_start_timeout_ms, opts \\ []) do
    case Vibe.Remote.connect() do
      {:ok, _node} -> :ok
      {:error, {:stale_server, _metadata}} -> restart_background(timeout_ms, opts)
      {:error, _reason} -> start_background(timeout_ms, opts)
    end
  end

  @spec start_background(non_neg_integer(), keyword()) :: :ok | {:error, term()}
  def start_background(timeout_ms \\ @default_start_timeout_ms, opts \\ []) do
    launch_background(opts)

    case wait(timeout_ms) do
      :ok ->
        :ok

      {:error, reason} ->
        Vibe.Server.cleanup_metadata()
        {:error, reason}
    end
  end

  @spec launch_background(keyword()) :: :ok
  def launch_background(opts \\ []) do
    log_path = Vibe.Paths.server_log()
    File.mkdir_p!(Path.dirname(log_path))

    command = "exec #{background_command(opts)} > #{shell_quote(log_path)} 2>&1 < /dev/null"

    :erlang.open_port({:spawn_executable, "/bin/sh"}, [
      :binary,
      :nouse_stdio,
      {:args, ["-c", command]}
    ])

    :ok
  end

  defp restart_background(timeout_ms, opts) do
    node = current_server_node()
    _ = Vibe.Server.stop()
    wait_for_shutdown(node, min(timeout_ms, @shutdown_grace_ms))
    start_background(timeout_ms, opts)
  end

  defp current_server_node do
    with {:ok, %{"node" => node_name}} <- Metadata.read(),
         true <- is_binary(node_name) do
      :erlang.binary_to_atom(node_name)
    else
      _other -> Vibe.Server.default_node_name()
    end
  end

  defp wait_for_shutdown(nil, _timeout_ms), do: :ok

  defp wait_for_shutdown(node, timeout_ms) do
    Node.monitor(node, true)

    if Node.connect(node) do
      receive do
        {:nodedown, ^node} -> :ok
      after
        timeout_ms -> :timeout
      end
    else
      :ok
    end
  after
    Node.monitor(node, false)
    flush_nodedown(node)
  end

  defp flush_nodedown(node) do
    receive do
      {:nodedown, ^node} -> :ok
    after
      0 -> :ok
    end
  end

  defp wait(timeout_ms) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    wait_until(deadline)
  end

  defp wait_until(deadline) do
    case Vibe.Remote.connect() do
      {:ok, _node} ->
        :ok

      {:error, reason} ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, reason}
        else
          Process.sleep(@connect_poll_interval_ms)
          wait_until(deadline)
        end
    end
  end

  defp background_command(opts) do
    server_args = server_start_args(opts)

    case :escript.script_name() do
      path when is_list(path) and path != [] ->
        path = path |> List.to_string() |> Path.expand()

        if Path.basename(path) in ["mix", "mix.bat"] do
          "sh -c #{shell_quote("cd #{shell_quote(File.cwd!())} && #{shell_quote(path)} vibe #{server_args}")}"
        else
          "#{shell_quote(path)} #{server_args}"
        end

      _other ->
        installed_command(opts)
    end
  rescue
    _error -> installed_command(opts)
  end

  defp installed_command(opts) do
    server_args = server_start_args(opts)

    case System.find_executable("vibe") do
      nil ->
        "sh -c #{shell_quote("cd #{shell_quote(File.cwd!())} && mix vibe #{server_args}")}"

      path ->
        "#{shell_quote(path)} #{server_args}"
    end
  end

  defp server_start_opts(opts) do
    [foreground: true]
    |> maybe_put(:ssh, opts[:ssh])
    |> maybe_put(:port, opts[:port])
  end

  defp server_start_args(opts) do
    ["server", "start", "--foreground"]
    |> maybe_append(opts[:ssh], "--ssh")
    |> maybe_append(opts[:port], "--port #{opts[:port]}")
    |> Enum.join(" ")
  end

  defp maybe_append(args, nil, _arg), do: args
  defp maybe_append(args, false, _arg), do: args
  defp maybe_append(args, _value, arg), do: List.insert_at(args, -1, arg)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, false), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp shell_quote(value), do: "'" <> String.replace(value, "'", "'\\''") <> "'"
end
