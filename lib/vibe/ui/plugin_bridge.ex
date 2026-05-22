defmodule Vibe.UI.PluginBridge do
  @moduledoc "Bridges plugin events into the session UI state loop."

  alias Vibe.Event
  alias Vibe.UI.State

  @ignored_events MapSet.new([
                    :plugin_status_updated,
                    :plugin_status_cleared,
                    :plugin_widget_updated,
                    :plugin_widget_cleared,
                    :notification_added,
                    :notification_expired
                  ])

  @spec dispatch(State.t(), Event.t()) :: :ok
  def dispatch(session_state, event) do
    if plugin_event?(event.type) and Process.whereis(Vibe.Plugin.Manager) do
      context = %{
        session_id: session_state.session_id,
        cwd: session_state.cwd,
        model: session_state.model,
        effort: session_state.effort
      }

      Task.Supervisor.start_child(Vibe.UI.PluginTaskSupervisor, fn ->
        Vibe.Plugin.Manager.dispatch(event.type, event.data, context)
      end)
    end

    :ok
  end

  @spec dispatch_lifecycle(atom(), map(), State.t(), boolean()) :: :ok
  def dispatch_lifecycle(type, data, session_state, enabled? \\ true) do
    if enabled? do
      dispatch(session_state, Event.new(type, session_state.session_id, data))
    else
      :ok
    end
  end

  defp plugin_event?(type), do: not MapSet.member?(@ignored_events, type)
end
