defmodule Vibe.Plugins.Notify.Terminal do
  @moduledoc """
  Desktop notifications via terminal OSC escape sequences.

  Sends both OSC 777 (urxvt-style) and OSC 9 (iTerm2-style) for broad
  terminal compatibility. Supported by Ghostty, iTerm2, WezTerm, foot,
  kitty, and most modern terminals.
  """

  @spec notify(String.t(), String.t()) :: :ok
  def notify(title, body) when is_binary(title) and is_binary(body) do
    if interactive?() do
      title = sanitize(title)
      body = sanitize(body)

      IO.write(:stderr, [
        osc_777(title, body),
        osc_9(title, body)
      ])
    end

    :ok
  rescue
    error ->
      require Logger
      Logger.debug("Desktop notification failed: #{Exception.message(error)}")
      :ok
  end

  @spec task_completed(String.t() | nil) :: :ok
  def task_completed(detail \\ nil) do
    notify("Vibe", detail || "Task completed")
  end

  @spec task_error(String.t() | nil) :: :ok
  def task_error(detail \\ nil) do
    notify("Vibe", detail || "Task failed")
  end

  defp osc_777(title, body), do: "\e]777;notify;#{title};#{body}\e\\"
  defp osc_9(title, body), do: "\e]9;#{title}: #{body}\e\\"

  defp interactive? do
    :prim_tty.isatty(:stderr)
  rescue
    _error -> false
  end

  defp sanitize(text) do
    text
    |> String.replace(~r/[;\x00-\x1f]/, "")
    |> String.slice(0, 200)
  end
end
