defmodule Vibe.Web.RuntimeLiveTest do
  use Vibe.WebCase, async: false

  test "renders" do
    conn = authenticated_conn() |> get("/runtime")

    assert html_response(conn, 200) =~ "Runtime"
    assert html_response(conn, 200) =~ "Top processes"
  end

  test "renders active runtime alerts" do
    :alarm_handler.set_alarm({{:disk_almost_full, ~c"/tmp"}, []})
    assert_active_alert(:disk_almost_full)

    conn = authenticated_conn() |> get("/runtime")
    html = html_response(conn, 200)

    assert html =~ "Disk almost full"
    assert html =~ "large writes"
  after
    :alarm_handler.clear_alarm({:disk_almost_full, ~c"/tmp"})
  end

  defp assert_active_alert(type) do
    deadline = System.monotonic_time(:millisecond) + 500
    wait_for_alert(type, deadline)
  end

  defp wait_for_alert(type, deadline) do
    if Enum.any?(Vibe.SystemAlarms.active(), &(&1.type == type)) do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(10)
        wait_for_alert(type, deadline)
      else
        flunk("active alert was not set")
      end
    end
  end
end
