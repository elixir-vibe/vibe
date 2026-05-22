defmodule Vibe.SystemAlarms do
  @moduledoc """
  Bridges BEAM/SASL alarms into Vibe's local telemetry stream.

  OTP services such as `:memsup` publish alarms through `:alarm_handler`,
  including memory pressure signals like `:system_memory_high_watermark`. Vibe
  records those alarms as sanitized telemetry so agents and dashboards can
  inspect runtime pressure without scraping logs.
  """

  use GenServer

  alias Vibe.SystemAlarms.{Active, Alert}

  require Logger

  @handler Vibe.SystemAlarms.Handler

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec installed?() :: boolean()
  def installed?, do: GenServer.call(__MODULE__, :installed?)

  @spec active() :: [Alert.t()]
  def active, do: Active.active() |> active_alerts()

  @spec alarms() :: {:ok, [term()]} | {:error, term()}
  def alarms do
    {:ok, :alarm_handler.get_alarms()}
  rescue
    exception -> {:error, exception}
  catch
    :exit, reason -> {:error, reason}
  end

  @impl true
  def init(_opts) do
    Active.reset()
    {:ok, %{installed?: install_handler()}}
  end

  @impl true
  def handle_call(:installed?, _from, state), do: {:reply, state.installed?, state}

  @impl true
  def handle_info({:system_alarm, action, alarm_id, description}, state) do
    alert = Alert.from_alarm(action, alarm_id, description)
    state = update_active_alerts(state, action, alert)
    record_alarm(action, alarm_id, description)
    emit_runtime_alert(action, alert)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{installed?: true}) do
    :alarm_handler.delete_alarm_handler(@handler)
    :ok
  rescue
    _exception -> :ok
  catch
    :exit, _reason -> :ok
  end

  def terminate(_reason, _state), do: :ok

  defp active_alerts(alerts), do: alerts

  defp install_handler do
    case Application.ensure_all_started(:sasl) do
      {:ok, _apps} ->
        _ = :alarm_handler.delete_alarm_handler(@handler)

        case :alarm_handler.add_alarm_handler(@handler, owner: self()) do
          :ok -> true
          {:error, reason} -> log_install_failure(reason)
        end

      {:error, reason} ->
        log_install_failure(reason)
    end
  rescue
    exception -> log_install_failure(exception)
  catch
    :exit, reason -> log_install_failure(reason)
  end

  defp log_install_failure(reason) do
    Logger.debug("System alarm handler unavailable: #{inspect(reason)}")
    false
  end

  defp update_active_alerts(state, :set, alert) do
    Active.put(alert)
    state
  end

  defp update_active_alerts(state, :clear, alert) do
    Active.delete(alert)
    state
  end

  defp emit_runtime_alert(action, alert) do
    {type, payload} =
      case action do
        :set -> {:runtime_alert_set, Vibe.Event.RuntimeAlert.set(alert)}
        :clear -> {:runtime_alert_clear, Vibe.Event.RuntimeAlert.cleared(alert)}
      end

    Vibe.Event.Bus.emit_all(type, payload)
  rescue
    exception -> Logger.debug("Runtime alert UI emission failed: #{Exception.message(exception)}")
  catch
    :exit, reason -> Logger.debug("Runtime alert UI emission failed: #{inspect(reason)}")
  end

  defp record_alarm(action, alarm_id, description) do
    type = alarm_type(alarm_id)

    Vibe.Telemetry.execute([:vibe, :system, :alarm, action], %{}, %{
      alarm_id: inspect(alarm_id),
      alarm_type: type,
      description: inspect(description, limit: 20)
    })

    maybe_log_alarm(action, type, alarm_id, description)
  end

  defp maybe_log_alarm(:set, :system_memory_high_watermark, alarm_id, description) do
    Logger.warning("System memory high watermark alarm set: #{inspect({alarm_id, description})}")
  end

  defp maybe_log_alarm(:clear, :system_memory_high_watermark, _alarm_id, _description) do
    Logger.info("System memory high watermark alarm cleared")
  end

  defp maybe_log_alarm(:set, :disk_almost_full, alarm_id, description) do
    Logger.warning("Disk almost full alarm set: #{inspect({alarm_id, description})}")
  end

  defp maybe_log_alarm(:clear, :disk_almost_full, alarm_id, _description) do
    Logger.info("Disk almost full alarm cleared: #{inspect(alarm_id)}")
  end

  defp maybe_log_alarm(_action, _type, _alarm_id, _description), do: :ok

  defp alarm_type({type, _details}) when is_atom(type), do: type
  defp alarm_type(type) when is_atom(type), do: type
  defp alarm_type(_alarm_id), do: :unknown
end
