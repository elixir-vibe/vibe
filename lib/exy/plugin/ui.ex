defmodule Exy.Plugin.UI do
  @moduledoc """
  UI context exposed to plugins and plugin background workers.

  Mirrors pi's small status-bar API: plugins set a keyed status string and Exy
  renderers decide where/how to show it. Passing `nil` clears the status.
  """

  alias Exy.UI.{Bus, Widget}

  @type session_id :: String.t()
  @type status_key :: String.t() | atom()

  @spec set_status(session_id(), status_key(), String.t() | nil) :: :ok | {:error, :not_found}
  def set_status(session_id, key, text) when is_binary(session_id) and is_nil(text) do
    Bus.emit(session_id, :plugin_status_cleared, %{key: normalize_key(key)})
  end

  def set_status(session_id, key, text) when is_binary(session_id) and is_binary(text) do
    Bus.emit(session_id, :plugin_status_updated, %{key: normalize_key(key), text: sanitize(text)})
  end

  @spec set_widget(session_id(), Widget.t()) :: :ok | {:error, :not_found}
  def set_widget(session_id, %Widget{} = widget) when is_binary(session_id) do
    Bus.emit(session_id, :plugin_widget_updated, %{widget: widget})
  end

  @spec set_widget(session_id(), status_key(), [String.t()] | String.t()) ::
          :ok | {:error, :not_found}
  def set_widget(session_id, key, content), do: set_widget(session_id, key, content, [])

  @spec set_widget(session_id(), status_key(), [String.t()] | String.t(), keyword()) ::
          :ok | {:error, :not_found}
  def set_widget(session_id, key, content, opts) when is_binary(session_id) do
    Bus.emit(session_id, :plugin_widget_updated, %{
      widget:
        Widget.lines(normalize_key(key), content,
          placement: Keyword.get(opts, :placement, :above_editor)
        )
    })
  end

  @spec set_progress(session_id(), status_key(), keyword()) :: :ok | {:error, :not_found}
  def set_progress(session_id, key, opts) when is_binary(session_id) do
    Bus.emit(session_id, :plugin_widget_updated, %{
      widget: Widget.progress(normalize_key(key), opts)
    })
  end

  @spec clear_widget(session_id(), status_key()) :: :ok | {:error, :not_found}
  def clear_widget(session_id, key) when is_binary(session_id) do
    Bus.emit(session_id, :plugin_widget_cleared, %{key: normalize_key(key)})
  end

  @spec set_working_message(session_id(), String.t() | nil) :: :ok | {:error, :not_found}
  def set_working_message(session_id, message) when is_binary(session_id) do
    Bus.emit(session_id, :working_message_updated, %{message: optional_sanitize(message)})
  end

  @spec set_hidden_thinking_label(session_id(), String.t() | nil) :: :ok | {:error, :not_found}
  def set_hidden_thinking_label(session_id, label) when is_binary(session_id) do
    Bus.emit(session_id, :hidden_thinking_label_updated, %{label: optional_sanitize(label)})
  end

  @spec set_title(session_id(), String.t() | nil) :: :ok | {:error, :not_found}
  def set_title(session_id, title) when is_binary(session_id) do
    Bus.emit(session_id, :title_updated, %{title: optional_sanitize(title)})
  end

  @spec notify(session_id(), String.t(), atom()) :: :ok | {:error, :not_found}
  def notify(session_id, text, level \\ :info) when is_binary(session_id) and is_binary(text) do
    Bus.emit(session_id, :notification_added, %{level: level, text: text})
  end

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key

  defp optional_sanitize(nil), do: nil
  defp optional_sanitize(text) when is_binary(text), do: sanitize(text)

  defp sanitize(text) do
    text
    |> String.replace(~r/[\r\n\t]/, " ")
    |> String.replace(~r/ +/, " ")
    |> String.trim()
  end
end
