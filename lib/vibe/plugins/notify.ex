defmodule Vibe.Plugins.Notify do
  @moduledoc """
  Plugin: desktop notification when the agent finishes or fails.

  Sends OSC escape sequences for broad terminal compatibility.
  See `Vibe.Notify` for protocol details.
  """
  use Vibe.Plugin

  alias Vibe.Plugins.Notify.Terminal

  @impl true
  def handle_event(%{type: :assistant_message_added}, _context, state) do
    Terminal.task_completed()
    {:ok, state}
  end

  def handle_event(%{type: :assistant_aborted, data: data}, _context, state) do
    reason = Map.get(data, :reason, "Task failed")

    unless cancelled?(reason) do
      Terminal.task_error(reason)
    end

    {:ok, state}
  end

  def handle_event(_event, _context, state), do: {:ok, state}

  defp cancelled?(reason) when is_binary(reason),
    do: String.downcase(reason) =~ "cancel"

  defp cancelled?(_reason), do: false
end
