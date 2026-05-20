defmodule Vibe.Remote.Transport.SSH do
  @moduledoc "SSH transport for constrained remote Vibe commands."

  @behaviour Vibe.Remote.Transport

  alias Vibe.Remote.SSH.Protocol

  defstruct [:connection, :host, :port, :user]

  @type t :: %__MODULE__{
          connection: term(),
          host: String.t(),
          port: non_neg_integer(),
          user: String.t()
        }

  @impl true
  def connect(target, opts) do
    with {:ok, {host, port}} <- target_host_port(target, opts) do
      user = Keyword.get(opts, :user, "vibe")
      password = Keyword.get_lazy(opts, :password, &Vibe.Server.Cookie.get/0)
      timeout = Keyword.get(opts, :timeout, 5_000)

      Application.ensure_all_started(:ssh)

      ssh_opts =
        [
          user: to_charlist(user),
          password: to_charlist(password),
          silently_accept_hosts: Keyword.get(opts, :silently_accept_hosts, false),
          user_interaction: false
        ]
        |> Keyword.merge(Keyword.get(opts, :ssh_options, []))

      case :ssh.connect(to_charlist(host), port, ssh_opts, timeout) do
        {:ok, connection} ->
          {:ok, %__MODULE__{connection: connection, host: host, port: port, user: user}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @spec close(t()) :: :ok
  def close(%__MODULE__{connection: connection}), do: :ssh.close(connection)

  @spec request(t(), map(), timeout()) :: {:ok, map()} | {:error, term()}
  def request(%__MODULE__{connection: connection}, payload, timeout \\ 5_000) do
    with {:ok, channel} <- :ssh_connection.session_channel(connection, timeout),
         :success <- :ssh_connection.exec(connection, channel, Protocol.request(payload), timeout),
         request_timeout = request_timeout(payload, timeout),
         {:ok, data} <- collect_response(connection, channel, request_timeout),
         {:ok, decoded} <- Jason.decode(data) do
      case decoded do
        %{"ok" => true, "data" => response} -> {:ok, response}
        %{"ok" => false, "error" => error} -> {:error, error}
        other -> {:error, {:invalid_response, other}}
      end
    else
      other -> other
    end
  end

  defp request_timeout(%{"op" => "sessions.next_events", "timeout_ms" => timeout_ms}, timeout)
       when is_integer(timeout_ms) and timeout_ms >= 0 do
    max(timeout, timeout_ms + 1_000)
  end

  defp request_timeout(_payload, timeout), do: timeout

  defp collect_response(connection, channel, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    collect_response(connection, channel, deadline, [])
  end

  defp collect_response(connection, channel, deadline, chunks) do
    receive do
      {:ssh_cm, ^connection, {:data, ^channel, 0, data}} ->
        collect_response(connection, channel, deadline, [chunks, data])

      {:ssh_cm, ^connection, {:exit_status, ^channel, 0}} ->
        collect_until_closed(connection, channel, deadline, chunks)

      {:ssh_cm, ^connection, {:exit_status, ^channel, status}} ->
        {:error, {:exit_status, status, IO.iodata_to_binary(chunks)}}

      {:ssh_cm, ^connection, {:closed, ^channel}} ->
        {:ok, IO.iodata_to_binary(chunks)}

      {:ssh_cm, ^connection, {:eof, ^channel}} ->
        collect_response(connection, channel, deadline, chunks)
    after
      timeout_left(deadline) -> {:error, :timeout}
    end
  end

  defp collect_until_closed(connection, channel, deadline, chunks) do
    receive do
      {:ssh_cm, ^connection, {:data, ^channel, 0, data}} ->
        collect_until_closed(connection, channel, deadline, [chunks, data])

      {:ssh_cm, ^connection, {:closed, ^channel}} ->
        {:ok, IO.iodata_to_binary(chunks)}

      {:ssh_cm, ^connection, {:eof, ^channel}} ->
        collect_until_closed(connection, channel, deadline, chunks)
    after
      timeout_left(deadline) -> {:ok, IO.iodata_to_binary(chunks)}
    end
  end

  defp timeout_left(deadline), do: max(deadline - System.monotonic_time(:millisecond), 0)

  defp target_host_port(nil, opts) do
    with {:ok, host} <- Keyword.fetch(opts, :host),
         {:ok, port} <- Keyword.fetch(opts, :port) do
      {:ok, {host, port}}
    else
      :error -> {:error, :missing_ssh_target}
    end
  end

  defp target_host_port({host, port}, _opts), do: {:ok, {to_string(host), port}}

  defp target_host_port(host, opts) when is_binary(host) do
    case Keyword.fetch(opts, :port) do
      {:ok, port} -> {:ok, {host, port}}
      :error -> {:error, :missing_ssh_port}
    end
  end
end
