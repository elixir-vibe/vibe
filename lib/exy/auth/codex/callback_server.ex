defmodule Exy.Auth.Codex.CallbackServer do
  @moduledoc false

  @redirect_port 1455

  @spec start_link(String.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(state) do
    parent = self()

    pid =
      spawn(fn ->
        {:ok, listen} =
          :gen_tcp.listen(@redirect_port, [
            :binary,
            active: false,
            packet: :raw,
            reuseaddr: true,
            ip: {127, 0, 0, 1}
          ])

        send(parent, {__MODULE__, :ready, self()})
        accept_once(listen, parent, state)
      end)

    receive do
      {__MODULE__, :ready, ^pid} -> {:ok, pid}
    after
      2_000 -> {:error, :callback_server_timeout}
    end
  rescue
    exception -> {:error, exception}
  end

  @spec wait_for_code(pid(), timeout()) :: String.t() | nil
  def wait_for_code(server, timeout) do
    ref = Process.monitor(server)

    receive do
      {__MODULE__, :code, code} ->
        Process.demonitor(ref, [:flush])
        code

      {:DOWN, ^ref, :process, ^server, _reason} ->
        nil
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        nil
    end
  end

  @spec stop(pid()) :: true
  def stop(pid) when is_pid(pid), do: Process.exit(pid, :shutdown)

  defp accept_once(listen, parent, state) do
    case :gen_tcp.accept(listen, 180_000) do
      {:ok, socket} ->
        {:ok, request} = :gen_tcp.recv(socket, 0, 5_000)
        {status, body, code} = parse_callback(request, state)

        response =
          "HTTP/1.1 #{status}\r\ncontent-type: text/html; charset=utf-8\r\ncontent-length: #{byte_size(body)}\r\n\r\n#{body}"

        :gen_tcp.send(socket, response)
        :gen_tcp.close(socket)
        :gen_tcp.close(listen)
        if code, do: send(parent, {__MODULE__, :code, code})

      _other ->
        :gen_tcp.close(listen)
    end
  end

  defp parse_callback(request, state) do
    [request_line | _] = String.split(request, "\r\n", parts: 2)

    with ["GET", target | _] <- String.split(request_line, " "),
         %URI{path: "/auth/callback", query: query} <- URI.parse(target),
         params <- URI.decode_query(query || ""),
         true <- params["state"] == state,
         code when is_binary(code) <- params["code"] do
      {"200 OK",
       "<html><body>OpenAI authentication completed. You can close this window.</body></html>",
       code}
    else
      _ -> {"400 Bad Request", "<html><body>OpenAI authentication failed.</body></html>", nil}
    end
  end
end
