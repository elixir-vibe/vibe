defmodule Exy.UI.PluginBridge do
  @moduledoc "Internal implementation module."
  @ignored_events MapSet.new([
                    :plugin_status_updated,
                    :plugin_status_cleared,
                    :plugin_widget_updated,
                    :plugin_widget_cleared,
                    :notification_added,
                    :notification_expired
                  ])

  @spec dispatch(Exy.UI.State.t(), Exy.UI.Event.t()) :: :ok
  def dispatch(ui_state, event) do
    if plugin_event?(event.type) and Process.whereis(Exy.Plugin.Manager) do
      context = %{
        session_id: ui_state.session_id,
        cwd: ui_state.cwd,
        model: ui_state.model,
        effort: ui_state.effort
      }

      Task.Supervisor.start_child(Exy.UI.PluginTaskSupervisor, fn ->
        Exy.Plugin.Manager.dispatch(event.type, event.data, context)
      end)
    end

    :ok
  end

  @spec dispatch_lifecycle(atom(), map(), Exy.UI.State.t(), boolean()) :: :ok
  def dispatch_lifecycle(type, data, ui_state, enabled? \\ true) do
    if enabled? do
      dispatch(ui_state, Exy.UI.Event.new(type, ui_state.session_id, data))
    else
      :ok
    end
  end

  defp plugin_event?(type), do: not MapSet.member?(@ignored_events, type)
end
