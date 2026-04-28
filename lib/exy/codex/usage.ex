defmodule Exy.Codex.Usage do
  @moduledoc """
  Codex subscription usage/limit awareness.

  Uses the public Codex CLI app-server JSON-RPC method discovered in the open
  Codex/CodexBar implementations: `account/rateLimits/read`. This avoids screen
  scraping `https://chatgpt.com/codex/settings/usage` and reuses the user's
  existing Codex login.
  """

  @rpc_args ["-s", "read-only", "-a", "untrusted", "app-server"]
  @rpc_line_length 65_536
  @rpc_response_timeout_ms 10_000

  @spec limits(keyword()) :: {:ok, map()} | {:error, term()}
  def limits(opts \\ []) do
    with {:ok, rpc} <- start_rpc(opts),
         {:ok, _} <-
           request(rpc, "initialize", %{clientInfo: %{name: "exy", version: version()}}, 1),
         :ok <- notify(rpc, "initialized"),
         {:ok, result} <- request(rpc, "account/rateLimits/read", nil, 2) do
      stop_rpc(rpc)
      {:ok, normalize(result)}
    else
      {:error, _} = error -> error
    end
  after
    :ok
  end

  @spec account(keyword()) :: {:ok, map()} | {:error, term()}
  def account(opts \\ []) do
    with {:ok, rpc} <- start_rpc(opts),
         {:ok, _} <-
           request(rpc, "initialize", %{clientInfo: %{name: "exy", version: version()}}, 1),
         :ok <- notify(rpc, "initialized"),
         {:ok, result} <- request(rpc, "account/read", nil, 2) do
      stop_rpc(rpc)
      {:ok, result}
    else
      {:error, _} = error -> error
    end
  after
    :ok
  end

  defp start_rpc(opts) do
    executable = Keyword.get(opts, :executable, System.get_env("EXY_CODEX") || "codex")

    port =
      Port.open({:spawn_executable, System.find_executable(executable) || executable}, [
        :binary,
        :exit_status,
        args: Keyword.get(opts, :args, @rpc_args),
        line: @rpc_line_length
      ])

    {:ok, %{port: port}}
  rescue
    exception -> {:error, Exception.message(exception)}
  end

  defp stop_rpc(%{port: port}) do
    Port.close(port)
  rescue
    _ -> :ok
  end

  defp request(rpc, method, params, id) do
    payload = %{jsonrpc: "2.0", id: id, method: method}
    payload = if params, do: Map.put(payload, :params, params), else: payload
    send_json(rpc, payload)
    await_response(id, @rpc_response_timeout_ms)
  end

  defp notify(rpc, method) do
    send_json(rpc, %{jsonrpc: "2.0", method: method})
  end

  defp send_json(%{port: port}, payload) do
    Port.command(port, Jason.encode!(payload) <> "\n")
    :ok
  end

  defp await_response(id, timeout) do
    receive do
      {_port, {:data, {:eol, line}}} ->
        with {:ok, message} <- Jason.decode(line),
             true <- Map.get(message, "id") == id do
          if error = message["error"] do
            {:error, error}
          else
            {:ok, message["result"] || %{}}
          end
        else
          _ -> await_response(id, timeout)
        end

      {_port, {:exit_status, status}} ->
        {:error, {:codex_exited, status}}
    after
      timeout -> {:error, :timeout}
    end
  end

  defp normalize(%{"rateLimits" => limits}), do: normalize_limits(limits)
  defp normalize(%{"rate_limits" => limits}), do: normalize_limits(limits)
  defp normalize(other), do: other

  defp normalize_limits(limits) do
    %{
      primary: normalize_window(limits["primary"]),
      secondary: normalize_window(limits["secondary"]),
      credits: limits["credits"]
    }
  end

  defp normalize_window(nil), do: nil

  defp normalize_window(window) do
    used = window["usedPercent"] || window["used_percent"]

    %{
      used_percent: used,
      remaining_percent: if(is_number(used), do: max(0, 100 - used), else: nil),
      window_minutes: window["windowDurationMins"] || window["window_duration_mins"],
      resets_at: window["resetsAt"] || window["resets_at"]
    }
  end

  defp version, do: Application.spec(:exy, :vsn) |> to_string()
end
