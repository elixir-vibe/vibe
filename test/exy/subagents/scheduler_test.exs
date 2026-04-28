defmodule Exy.Subagents.SchedulerTest do
  use ExUnit.Case, async: false

  @schedule_interval_ms 60_000

  setup do
    subagents_dir =
      Path.join(System.tmp_dir!(), "exy-subagent-schedules-#{System.unique_integer([:positive])}")

    session_dir =
      Path.join(System.tmp_dir!(), "exy-subagent-sessions-#{System.unique_integer([:positive])}")

    old_subagents = Application.get_env(:exy, :subagents_dir)
    old_sessions = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :subagents_dir, subagents_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      restore_app_env(:subagents_dir, old_subagents)
      restore_app_env(:session_dir, old_sessions)
      File.rm_rf(subagents_dir)
      File.rm_rf(session_dir)
    end)

    {:ok, subagents_dir: subagents_dir}
  end

  test "schedules, persists, runs, and unschedules background subagents" do
    assert {:ok, schedule} =
             Exy.Subagents.schedule("scheduled task",
               every: @schedule_interval_ms,
               ask_fun: fn text, _opts -> {:ok, "scheduled: #{text}"} end
             )

    assert Enum.any?(Exy.Subagents.scheduled(), &(&1.id == schedule.id))
    assert Enum.any?(Exy.Subagents.Store.schedules(), &(&1.id == schedule.id))
    assert :ok = Exy.Subagents.unschedule(schedule.id)
    refute Enum.any?(Exy.Subagents.scheduled(), &(&1.id == schedule.id))
  end

  defp restore_app_env(key, nil), do: Application.delete_env(:exy, key)
  defp restore_app_env(key, value), do: Application.put_env(:exy, key, value)
end
