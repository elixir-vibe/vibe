defmodule Exy.CLI.Server do
  @moduledoc false

  alias Exy.CLI.Output
  alias Exy.Server.Metadata

  @spec command([String.t()], keyword()) :: :ok | {:error, term()}
  def command(["start"], opts), do: command(["start", "--auto"], opts)

  def command(["start", _mode], opts) do
    if opts[:foreground] do
      Exy.Server.start(foreground: true)
    else
      Output.print(start_background(), opts)
    end
  end

  def command(["status"], opts), do: Output.print(Exy.Server.status(), opts)
  def command(["stop"], opts), do: Output.print(Exy.Server.stop(), opts)

  def command(["restart"], opts) do
    node = current_server_node()
    _ = Exy.Server.stop()
    wait_for_shutdown(node, 5_000)

    if opts[:foreground] do
      Exy.Server.start(foreground: true)
    else
      Output.print(start_background(), opts)
    end
  end

  def command(_args, _opts) do
    Output.error(
      "Usage: exy server start [--foreground] | restart [--foreground] | status | stop"
    )

    {:error, :invalid_server_command}
  end

  @spec ensure_running(non_neg_integer()) :: :ok | {:error, term()}
  def ensure_running(timeout_ms \\ 20_000) do
    case Exy.Remote.connect() do
      {:ok, _node} -> :ok
      {:error, {:stale_server, _metadata}} -> restart_background(timeout_ms)
      {:error, _reason} -> start_background(timeout_ms)
    end
  end

  @spec start_background(non_neg_integer()) :: :ok | {:error, term()}
  def start_background(timeout_ms \\ 20_000) do
    launch_background()

    case wait(timeout_ms) do
      :ok ->
        :ok

      {:error, reason} ->
        Exy.Server.cleanup_metadata()
        {:error, reason}
    end
  end

  @spec launch_background() :: :ok
  def launch_background do
    log_path = Exy.Paths.server_log()
    File.mkdir_p!(Path.dirname(log_path))

    command = "exec #{background_command()} > #{shell_quote(log_path)} 2>&1 < /dev/null"

    :erlang.open_port({:spawn_executable, "/bin/sh"}, [
      :binary,
      :nouse_stdio,
      {:args, ["-c", command]}
    ])

    :ok
  end

  defp restart_background(timeout_ms) do
    node = current_server_node()
    _ = Exy.Server.stop()
    wait_for_shutdown(node, min(timeout_ms, 5_000))
    start_background(timeout_ms)
  end

  defp current_server_node do
    with {:ok, %{"node" => node_name}} <- Metadata.read(),
         true <- is_binary(node_name) do
      String.to_atom(node_name)
    else
      _other -> Exy.Server.default_node_name()
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
    case Exy.Remote.connect() do
      {:ok, _node} ->
        :ok

      {:error, reason} ->
        if System.monotonic_time(:millisecond) >= deadline do
          {:error, reason}
        else
          Process.sleep(100)
          wait_until(deadline)
        end
    end
  end

  defp background_command do
    case :escript.script_name() do
      path when is_list(path) and path != [] ->
        path = path |> List.to_string() |> Path.expand()

        if Path.basename(path) in ["mix", "mix.bat"] do
          "sh -c #{shell_quote("cd #{shell_quote(File.cwd!())} && #{shell_quote(path)} exy server start --foreground")}"
        else
          "#{shell_quote(path)} server start --foreground"
        end

      _other ->
        installed_command()
    end
  rescue
    _error -> installed_command()
  end

  defp installed_command do
    case System.find_executable("exy") do
      nil ->
        "sh -c #{shell_quote("cd #{shell_quote(File.cwd!())} && mix exy server start --foreground")}"

      path ->
        "#{shell_quote(path)} server start --foreground"
    end
  end

  defp shell_quote(value), do: "'" <> String.replace(value, "'", "'\\''") <> "'"
end
