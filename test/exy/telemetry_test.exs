defmodule Exy.TelemetryTest do
  use ExUnit.Case, async: false

  setup do
    previous_home = System.get_env("EXY_HOME")

    home =
      Path.join(System.tmp_dir!(), "exy-telemetry-test-#{System.unique_integer([:positive])}")

    System.put_env("EXY_HOME", home)
    File.rm_rf!(home)

    on_exit(fn ->
      if previous_home,
        do: System.put_env("EXY_HOME", previous_home),
        else: System.delete_env("EXY_HOME")

      File.rm_rf!(home)
    end)

    _ = Exy.Telemetry.clear()
    :ok
  end

  test "stores telemetry in SQLite and exposes recent events" do
    Exy.Telemetry.execute([:exy, :session, :command, :start], %{system_time: 1}, %{
      session_id: "self",
      command: :test
    })

    assert_event(fn event -> event.event == [:exy, :session, :command, :start] end)

    assert Exy.Telemetry.path() == Path.expand(Exy.Paths.database())

    assert [%{metadata: metadata}] = Exy.Telemetry.recent(1)
    assert metadata.session_id == "self"

    assert %{count: 1, by_event: %{"exy.session.command.start" => 1}} = Exy.Telemetry.summary()
  end

  test "span records start and stop events" do
    assert Exy.Telemetry.span([:exy, :plugin, :dispatch], %{event_type: :test}, fn -> :ok end) ==
             :ok

    assert_event(fn event -> event.event == [:exy, :plugin, :dispatch, :start] end)
    assert_event(fn event -> event.event == [:exy, :plugin, :dispatch, :stop] end)
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
