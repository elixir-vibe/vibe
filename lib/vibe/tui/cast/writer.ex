defmodule Vibe.TUI.Cast.Writer do
  @moduledoc false

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: opts |> normalize_opts() |> TTYCast.Writer.start_link()

  @spec output(pid() | nil, IO.chardata()) :: :ok
  def output(pid, iodata), do: TTYCast.Writer.write(pid, iodata)

  @spec input(pid() | nil, IO.chardata()) :: :ok
  def input(pid, iodata), do: TTYCast.Writer.input(pid, iodata)

  @spec input_redacted(pid() | nil, non_neg_integer()) :: :ok
  def input_redacted(pid, byte_count), do: TTYCast.Writer.input_redacted(pid, byte_count)

  @spec key(pid() | nil, term()) :: :ok
  def key(nil, _event), do: :ok
  def key(pid, event), do: TTYCast.Writer.event(pid, :"vibe.key", simplify_key(event))

  @spec resize(pid() | nil, pos_integer(), pos_integer()) :: :ok
  def resize(pid, columns, rows), do: TTYCast.Writer.resize(pid, columns, rows)

  @spec app_event(pid() | nil, term()) :: :ok
  def app_event(nil, _event), do: :ok

  def app_event(pid, event),
    do: TTYCast.Writer.event(pid, :"vibe.app_event", sanitize_event(event))

  @spec trace_frame(pid() | nil, term()) :: :ok
  def trace_frame(pid, payload), do: TTYCast.Writer.event(pid, :"vibe.trace_frame", payload)

  @spec trace_snapshot(pid() | nil, term()) :: :ok
  def trace_snapshot(pid, payload), do: TTYCast.Writer.event(pid, :"vibe.trace_snapshot", payload)

  @spec close(pid() | nil) :: :ok
  def close(pid), do: TTYCast.Writer.close(pid)

  defp normalize_opts(opts) do
    Keyword.put_new(opts, :input_policy, input_policy(opts))
  end

  defp input_policy(opts) do
    cond do
      Keyword.get(opts, :record_input) -> :raw
      System.get_env("VIBE_TUI_CAST_INPUT") == "1" -> :raw
      true -> :redacted
    end
  end

  defp simplify_key(%Ghostty.KeyEvent{} = event) do
    %{key: event.key, mods: event.mods, action: event.action, utf8: event.utf8}
  end

  defp simplify_key(event), do: event

  defp sanitize_event(%{id: id, type: type, session_id: session_id}) do
    %{id: id, type: type, session_id: session_id}
  end

  defp sanitize_event(%{type: type}), do: %{type: type}
  defp sanitize_event(event) when is_atom(event), do: event

  defp sanitize_event(event) when is_struct(event),
    do: event |> Map.from_struct() |> sanitize_map()

  defp sanitize_event(event) when is_map(event), do: sanitize_map(event)
  defp sanitize_event(_event), do: :redacted

  defp sanitize_map(map) do
    map
    |> Map.take([:id, :type, :session_id, :status, :kind])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
