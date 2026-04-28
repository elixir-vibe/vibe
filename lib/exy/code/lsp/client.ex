defmodule Exy.Code.LSP.Client do
  @moduledoc false

  use GenServer

  @default_request_timeout_ms 30_000
  @request_call_overhead_ms 1_000
  @default_diagnostics_timeout_ms 2_000
  @diagnostics_call_overhead_ms 500
  @initialize_timeout_ms 5_000

  def start_link(opts) do
    cwd = Keyword.fetch!(opts, :cwd)
    GenServer.start_link(__MODULE__, opts, name: via(cwd))
  end

  def ensure_started(cwd) do
    cwd = Path.expand(cwd)

    case Registry.lookup(Exy.Registry, {:lsp, cwd}) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        spec = %{
          id: {:exy_lsp, cwd},
          start: {__MODULE__, :start_link, [[cwd: cwd]]},
          restart: :temporary
        }

        case DynamicSupervisor.start_child(Exy.Code.LSP.Supervisor, spec) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  def request(pid, method, params \\ %{}, timeout \\ @default_request_timeout_ms) do
    GenServer.call(pid, {:request, method, params}, timeout + @request_call_overhead_ms)
  catch
    :exit, {:timeout, _call} -> {:error, "Expert LSP request timed out"}
    :exit, reason -> {:error, "Expert LSP request failed: #{inspect(reason)}"}
  end

  def notify(pid, method, params \\ %{}) do
    GenServer.cast(pid, {:notify, method, params})
  end

  def diagnostics(pid, file, timeout \\ @default_diagnostics_timeout_ms) do
    GenServer.call(
      pid,
      {:diagnostics, Path.expand(file)},
      timeout + @diagnostics_call_overhead_ms
    )
  end

  @impl true
  def init(opts) do
    cwd = Keyword.fetch!(opts, :cwd)
    command = expert_command()

    port =
      Port.open({:spawn_executable, command}, [
        :binary,
        :exit_status,
        {:args, expert_args(command)},
        {:cd, cwd},
        :stderr_to_stdout
      ])

    Registry.register(Exy.Registry, {:lsp, cwd}, [])

    state = %{
      cwd: cwd,
      port: port,
      seq: 0,
      buffer: <<>>,
      pending: %{},
      diagnostics: %{},
      initialized?: false
    }

    {:ok, state, {:continue, :initialize}}
  end

  @impl true
  def handle_continue(:initialize, state) do
    root_uri = path_uri(state.cwd)

    payload = %{
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: %{
        processId: System.pid() |> String.to_integer(),
        rootUri: root_uri,
        capabilities: %{general: %{positionEncodings: ["utf-16"]}},
        workspaceFolders: [%{uri: root_uri, name: Path.basename(state.cwd)}]
      }
    }

    send_payload(state.port, payload)
    {:noreply, %{state | seq: 1, pending: %{1 => :initialize}}, @initialize_timeout_ms}
  end

  @impl true
  def handle_call({:request, method, params}, from, state) do
    id = state.seq + 1
    payload = %{jsonrpc: "2.0", id: id, method: method, params: params}
    send_payload(state.port, payload)
    {:noreply, %{state | seq: id, pending: Map.put(state.pending, id, from)}}
  end

  def handle_call({:diagnostics, file}, _from, state) do
    {:reply, Map.get(state.diagnostics, path_uri(file), []), state}
  end

  @impl true
  def handle_cast({:notify, method, params}, state) do
    send_payload(state.port, %{jsonrpc: "2.0", method: method, params: params})
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    {messages, buffer} = parse_messages(state.buffer <> data, [])
    state = Enum.reduce(messages, %{state | buffer: buffer}, &handle_message/2)
    {:noreply, state}
  end

  def handle_info(:timeout, %{initialized?: false} = state) do
    for {_id, from} <- state.pending, from != :initialize do
      GenServer.reply(from, {:error, "Expert initialize timed out"})
    end

    {:stop, :initialize_timeout, %{state | pending: %{}}}
  end

  def handle_info(:timeout, state), do: {:noreply, state}

  def handle_info({_port, {:exit_status, status}}, state) do
    for {_id, from} <- state.pending do
      GenServer.reply(from, {:error, "Expert exited with status #{status}"})
    end

    {:stop, {:expert_exit, status}, %{state | pending: %{}}}
  end

  defp handle_message(%{"id" => id} = message, state) do
    case Map.pop(state.pending, id) do
      {nil, pending} ->
        %{state | pending: pending}

      {:initialize, pending} ->
        send_payload(state.port, %{jsonrpc: "2.0", method: "initialized", params: %{}})
        %{state | pending: pending, initialized?: true}

      {from, pending} ->
        GenServer.reply(from, response_result(message))
        %{state | pending: pending}
    end
  end

  defp handle_message(%{"method" => "textDocument/publishDiagnostics", "params" => params}, state) do
    uri = params["uri"]
    diagnostics = Map.get(params, "diagnostics", [])
    %{state | diagnostics: Map.put(state.diagnostics, uri, diagnostics)}
  end

  defp handle_message(_message, state), do: state

  defp response_result(%{"error" => error}), do: {:error, error}
  defp response_result(%{"result" => result}), do: {:ok, result}
  defp response_result(_), do: {:ok, nil}

  defp send_payload(port, payload) do
    json = Jason.encode!(payload)
    Port.command(port, ["Content-Length: ", Integer.to_string(byte_size(json)), "\r\n\r\n", json])
  end

  defp parse_messages(buffer, acc) do
    case parse_one(buffer) do
      {:ok, message, rest} -> parse_messages(rest, [message | acc])
      :more -> {Enum.reverse(acc), buffer}
    end
  end

  defp parse_one(buffer) do
    with [headers, rest] <- :binary.split(buffer, "\r\n\r\n"),
         {:ok, length} <- content_length(headers),
         true <- byte_size(rest) >= length do
      <<body::binary-size(length), tail::binary>> = rest
      {:ok, Jason.decode!(body), tail}
    else
      _ -> :more
    end
  end

  defp content_length(headers) do
    headers
    |> String.split("\r\n")
    |> Enum.find_value(fn line ->
      case String.split(line, ":", parts: 2) do
        [key, value] ->
          if String.downcase(key) == "content-length",
            do: {:ok, value |> String.trim() |> String.to_integer()}

        _ ->
          nil
      end
    end)
    |> case do
      nil -> :error
      result -> result
    end
  rescue
    ArgumentError -> :error
  end

  def path_uri(path) do
    path = Path.expand(path)
    "file://" <> URI.encode(path, &(&1 == ?/ or URI.char_unreserved?(&1)))
  end

  defp expert_command do
    cond do
      System.get_env("EXY_EXPERT") ->
        System.get_env("EXY_EXPERT")

      System.find_executable("expert") ->
        System.find_executable("expert")

      System.find_executable("start_expert") ->
        System.find_executable("start_expert")

      true ->
        raise "Expert executable not found. Install expert or set EXY_EXPERT=/path/to/expert"
    end
  end

  defp expert_args(_command), do: ["--stdio"]

  defp via(cwd), do: {:via, Registry, {Exy.Registry, {:lsp, Path.expand(cwd)}}}
end
