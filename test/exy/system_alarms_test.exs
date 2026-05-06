defmodule Exy.SystemAlarmsTest do
  use ExUnit.Case, async: false

  setup do
    _ = Exy.Telemetry.clear()
    :ok
  end

  test "records SASL memory high watermark alarms as telemetry" do
    assert Exy.SystemAlarms.installed?()

    :alarm_handler.set_alarm({{:system_memory_high_watermark, []}, []})

    assert_event(fn event ->
      event.event == [:exy, :system, :alarm, :set] and
        event.metadata.alarm_type == "system_memory_high_watermark"
    end)

    :alarm_handler.clear_alarm({:system_memory_high_watermark, []})

    assert_event(fn event ->
      event.event == [:exy, :system, :alarm, :clear] and
        event.metadata.alarm_type == "system_memory_high_watermark"
    end)
  end

  defp assert_event(fun) do
    deadline = System.monotonic_time(:millisecond) + 500
    wait_for_event(fun, deadline)
  end

  defp wait_for_event(fun, deadline) do
    if Enum.any?(Exy.Telemetry.all(), fun) do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(10)
        wait_for_event(fun, deadline)
      else
        flunk("telemetry event was not stored")
      end
    end
  end
end
