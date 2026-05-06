defmodule Vibe.SystemAlarmsTest do
  use ExUnit.Case, async: false

  setup do
    _ = Vibe.Telemetry.clear()
    :ok
  end

  test "records SASL memory high watermark alarms as telemetry" do
    assert Vibe.SystemAlarms.installed?()

    :alarm_handler.set_alarm({{:system_memory_high_watermark, []}, []})

    assert_event(fn event ->
      event.event == [:vibe, :system, :alarm, :set] and
        event.metadata.alarm_type == "system_memory_high_watermark"
    end)

    :alarm_handler.clear_alarm({:system_memory_high_watermark, []})

    assert_event(fn event ->
      event.event == [:vibe, :system, :alarm, :clear] and
        event.metadata.alarm_type == "system_memory_high_watermark"
    end)
  end

  test "new sessions start with currently active runtime alerts" do
    assert Vibe.SystemAlarms.installed?()
    :alarm_handler.set_alarm({{:disk_almost_full, ~c"/tmp"}, []})
    assert_active_alert(:disk_almost_full)

    {:ok, session} = Vibe.Session.start_link(session_id: "alarm-initial-ui-test", persist?: false)
    assert_session_alert(session, :disk_almost_full)
  after
    :alarm_handler.clear_alarm({:disk_almost_full, ~c"/tmp"})
  end

  test "records SASL disk almost full alarms as telemetry and semantic UI state" do
    assert Vibe.SystemAlarms.installed?()
    {:ok, session} = Vibe.Session.start_link(session_id: "alarm-ui-test", persist?: false)

    :alarm_handler.set_alarm({{:disk_almost_full, ~c"/tmp"}, []})

    assert_event(fn event ->
      event.event == [:vibe, :system, :alarm, :set] and
        event.metadata.alarm_type == "disk_almost_full" and
        event.metadata.alarm_id =~ "/tmp"
    end)

    assert_active_alert(:disk_almost_full)
    assert_session_alert(session, :disk_almost_full)

    :alarm_handler.clear_alarm({:disk_almost_full, ~c"/tmp"})

    assert_event(fn event ->
      event.event == [:vibe, :system, :alarm, :clear] and
        event.metadata.alarm_type == "disk_almost_full"
    end)

    assert_cleared_alert(:disk_almost_full)
  end

  defp assert_active_alert(type) do
    deadline = System.monotonic_time(:millisecond) + 500

    wait_until(deadline, "active alert was not set", fn ->
      Enum.any?(Vibe.SystemAlarms.active(), &(&1.type == type))
    end)
  end

  defp assert_cleared_alert(type) do
    deadline = System.monotonic_time(:millisecond) + 500

    wait_until(deadline, "active alert was not cleared", fn ->
      Enum.all?(Vibe.SystemAlarms.active(), &(&1.type != type))
    end)
  end

  defp assert_session_alert(session, type) do
    deadline = System.monotonic_time(:millisecond) + 500

    wait_until(deadline, "session alert was not set", fn ->
      session
      |> Vibe.Session.state()
      |> Map.get(:runtime_alerts)
      |> Map.values()
      |> Enum.any?(&(&1.type == type))
    end)
  end

  defp assert_event(fun) do
    deadline = System.monotonic_time(:millisecond) + 500
    wait_for_event(fun, deadline)
  end

  defp wait_for_event(fun, deadline) do
    wait_until(deadline, "telemetry event was not stored", fn ->
      Enum.any?(Vibe.Telemetry.all(), fun)
    end)
  end

  defp wait_until(deadline, failure, fun) do
    cond do
      fun.() ->
        :ok

      System.monotonic_time(:millisecond) < deadline ->
        Process.sleep(10)
        wait_until(deadline, failure, fun)

      true ->
        flunk(failure)
    end
  end
end
