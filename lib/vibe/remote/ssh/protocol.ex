defmodule Vibe.Remote.SSH.Protocol do
  @moduledoc "Versioned JSON command protocol for the Vibe SSH transport."

  alias Vibe.Remote.SSH.Attachment
  alias Vibe.UI.Command

  @version 1

  @spec handle_exec(charlist() | binary(), keyword()) :: {:ok, iodata()} | {:error, iodata()}
  def handle_exec(command, _opts \\ []) do
    command
    |> IO.iodata_to_binary()
    |> Jason.decode()
    |> case do
      {:ok, request} -> encode(handle(request))
      {:error, error} -> encode_error(:invalid_json, Exception.message(error))
    end
  end

  @spec request(map()) :: binary()
  def request(payload) do
    payload
    |> Map.put_new("v", @version)
    |> Jason.encode!()
  end

  defp handle(%{"v" => @version, "op" => "ping"}) do
    {:ok, %{"pong" => true, "version" => Vibe.Build.version(), "build_id" => Vibe.Build.id()}}
  end

  defp handle(%{"v" => @version, "op" => "sessions.list"}) do
    {:ok, %{"sessions" => Vibe.Session.list()}}
  end

  defp handle(%{"v" => @version, "op" => "sessions.active_count"}) do
    {:ok, %{"active_count" => Vibe.Session.active_count()}}
  end

  defp handle(%{"v" => @version, "op" => "sessions.start"} = request) do
    opts = request |> Map.get("opts", %{}) |> session_opts()

    with {:ok, pid} <- Vibe.Session.start(opts) do
      {:ok, %{"session" => %{"id" => Vibe.Session.state(pid).session_id}}}
    end
  end

  defp handle(%{
         "v" => @version,
         "op" => "sessions.send_prompt",
         "session_id" => session_id,
         "text" => text
       })
       when is_binary(session_id) and is_binary(text) do
    with {:ok, pid} <- Vibe.Session.lookup(session_id),
         :ok <- Vibe.Session.dispatch(pid, %Command{type: :submit_prompt, data: %{text: text}}) do
      {:ok, %{"sent" => true, "session_id" => session_id}}
    end
  end

  defp handle(%{"v" => @version, "op" => "sessions.attach", "session_id" => session_id})
       when is_binary(session_id) do
    with {:ok, attachment} <- Attachment.start(session_id) do
      {:ok,
       %{
         "attachment_id" => attachment.id,
         "state" => attachment.state,
         "cursor" => attachment.cursor
       }}
    end
  end

  defp handle(
         %{"v" => @version, "op" => "sessions.next_events", "attachment_id" => attachment_id} =
           request
       )
       when is_binary(attachment_id) do
    timeout_ms = request |> Map.get("timeout_ms", 30_000) |> normalize_timeout()

    with {:ok, events} <- Attachment.next_events(attachment_id, timeout_ms) do
      {:ok, %{"session_events" => events}}
    end
  end

  defp handle(%{"v" => @version, "op" => "sessions.detach", "attachment_id" => attachment_id})
       when is_binary(attachment_id) do
    with :ok <- Attachment.detach(attachment_id) do
      {:ok, %{"detached" => true}}
    end
  end

  defp handle(%{"v" => version}) when version != @version do
    {:error, %{"reason" => "unsupported_version", "supported" => @version}}
  end

  defp handle(%{"op" => op}) do
    {:error, %{"reason" => "unsupported_op", "op" => op}}
  end

  defp handle(_request), do: {:error, %{"reason" => "invalid_request"}}

  defp session_opts(opts) when is_map(opts) do
    opts
    |> Enum.reduce([], fn
      {"session_id", value}, acc when is_binary(value) -> Keyword.put(acc, :session_id, value)
      {"persist?", value}, acc when is_boolean(value) -> Keyword.put(acc, :persist?, value)
      {"persist", value}, acc when is_boolean(value) -> Keyword.put(acc, :persist?, value)
      _entry, acc -> acc
    end)
  end

  defp session_opts(_opts), do: []

  defp normalize_timeout(timeout) when is_integer(timeout) and timeout >= 0, do: timeout
  defp normalize_timeout(_timeout), do: 30_000

  defp encode({:ok, data}) do
    {:ok, [Jason.encode!(Vibe.Transport.JSON.value(%{"ok" => true, "data" => data})), "\n"]}
  end

  defp encode({:error, data}) do
    {:ok,
     [
       Jason.encode!(
         Vibe.Transport.JSON.value(%{"ok" => false, "error" => normalize_error(data)})
       ),
       "\n"
     ]}
  end

  defp encode_error(reason, message) do
    {:ok,
     [
       Jason.encode!(
         Vibe.Transport.JSON.value(%{
           "ok" => false,
           "error" => %{"reason" => reason, "message" => message}
         })
       ),
       "\n"
     ]}
  end

  defp normalize_error(error) when is_map(error), do: error
  defp normalize_error(error) when is_atom(error), do: %{"reason" => Atom.to_string(error)}
  defp normalize_error(error), do: %{"reason" => inspect(error)}
end
