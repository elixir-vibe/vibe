defmodule Vibe.Plugins.NotifyTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Vibe.Plugins.Notify.Terminal

  test "notify sends OSC escape sequences to stderr" do
    output = capture_io(:stderr, fn -> Terminal.notify("Title", "Body") end)
    assert output =~ "\e]777;notify;Title;Body\e\\"
    assert output =~ "\e]9;Title: Body\e\\"
  end

  test "sanitizes control characters" do
    output = capture_io(:stderr, fn -> Terminal.notify("A;B\nC", "D\x00E") end)
    assert output =~ "ABC"
    assert output =~ "DE"
  end

  test "task_completed sends notification" do
    output = capture_io(:stderr, fn -> Terminal.task_completed() end)
    assert output =~ "Task completed"
  end

  test "task_error sends notification" do
    output = capture_io(:stderr, fn -> Terminal.task_error("timeout") end)
    assert output =~ "timeout"
  end

  test "plugin handles assistant_message_added event" do
    output =
      capture_io(:stderr, fn ->
        {result, _state} =
          Vibe.Plugins.Notify.handle_event(
            %{type: :assistant_message_added, data: %{}},
            %{},
            %{}
          )

        assert result == :ok
      end)

    assert output =~ "Task completed"
  end

  test "plugin handles assistant_aborted event" do
    output =
      capture_io(:stderr, fn ->
        {result, _state} =
          Vibe.Plugins.Notify.handle_event(
            %{type: :assistant_aborted, data: %{reason: "rate limited"}},
            %{},
            %{}
          )

        assert result == :ok
      end)

    assert output =~ "rate limited"
  end

  test "plugin skips notification on cancel" do
    output =
      capture_io(:stderr, fn ->
        Vibe.Plugins.Notify.handle_event(
          %{type: :assistant_aborted, data: %{reason: "Cancelled."}},
          %{},
          %{}
        )
      end)

    refute output =~ "Cancelled"
  end
end
