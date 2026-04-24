defmodule Exy.Plugin.UI do
  @moduledoc """
  UI context exposed to plugins and plugin background workers.

  Mirrors pi's small status-bar API: plugins set a keyed status string and Exy
  renderers decide where/how to show it. Passing `nil` clears the status.
  """

  alias Exy.UI.Bus

  @type session_id :: String.t()
  @type status_key :: String.t() | atom()

  @spec set_status(session_id(), status_key(), String.t() | nil) :: :ok | {:error, :not_found}
  def set_status(session_id, key, text) when is_binary(session_id) and is_nil(text) do
    Bus.emit(session_id, :plugin_status_cleared, %{key: normalize_key(key)})
  end

  def set_status(session_id, key, text) when is_binary(session_id) and is_binary(text) do
    Bus.emit(session_id, :plugin_status_updated, %{key: normalize_key(key), text: sanitize(text)})
  end

  @spec notify(session_id(), String.t(), atom()) :: :ok | {:error, :not_found}
  def notify(session_id, text, level \\ :info) when is_binary(session_id) and is_binary(text) do
    Bus.emit(session_id, :notification_added, %{level: level, text: text})
  end

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key

  defp sanitize(text) do
    text
    |> String.replace(~r/[\r\n\t]/, " ")
    |> String.replace(~r/ +/, " ")
    |> String.trim()
  end
end
