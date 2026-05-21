defmodule Vibe.TelemetryTest do
  use ExUnit.Case, async: false

  setup do
    previous_home = System.get_env("VIBE_HOME")

    home =
      Path.join(System.tmp_dir!(), "vibe-telemetry-test-#{System.unique_integer([:positive])}")

    System.put_env("VIBE_HOME", home)
    File.rm_rf!(home)

    on_exit(fn ->
      if previous_home,
        do: System.put_env("VIBE_HOME", previous_home),
        else: System.delete_env("VIBE_HOME")

      File.rm_rf!(home)
    end)

    _ = Vibe.Telemetry.clear()
    :ok
  end

  test "stores telemetry in SQLite and exposes recent events" do
    Vibe.Telemetry.execute([:vibe, :session, :command, :start], %{system_time: 1}, %{
      session_id: "self",
      command: :test
    })

    assert_event(fn event -> event.event == [:vibe, :session, :command, :start] end)

    assert Vibe.Telemetry.path() == Path.expand(Vibe.Paths.database())

    assert [%{metadata: metadata}] = Vibe.Telemetry.recent(1)
    assert metadata.session_id == "self"

    summary = Vibe.Telemetry.summary()
    assert summary.by_event["vibe.session.command.start"] == 1
    assert summary.count >= 1
  end

  test "external telemetry metadata is redacted before storage" do
    Vibe.Telemetry.execute([:finch, :request, :start], %{system_time: 1}, %{
      request: %{
        method: "POST",
        host: "example.test",
        path: "/v1/messages",
        headers: [{"authorization", "Bearer secret"}],
        body: "raw prompt"
      }
    })

    %{metadata: metadata} =
      assert_event(fn event ->
        event.event == [:finch, :request, :start] and
          get_in(event.metadata, [:request, "host"]) == "example.test"
      end)

    assert metadata.request["host"] == "example.test"
    refute inspect(metadata) =~ "secret"
    refute inspect(metadata) =~ "raw prompt"
  end

  test "stores mixed atom and string telemetry metadata as JSON-safe maps" do
    Vibe.Telemetry.execute([:finch, :request, :stop], %{duration: 1}, %{
      :request => %{method: "POST", host: "auth.openai.com", path: "/oauth/token"},
      :result => {:ok, %{:status => 200, "body" => <<1, 2, 3>>}},
      "name" => Req.Finch
    })

    %{metadata: metadata} =
      assert_event(fn event ->
        event.event == [:finch, :request, :stop] and
          get_in(event.metadata, [:request, "host"]) == "auth.openai.com"
      end)

    assert metadata.request["host"] == "auth.openai.com"
    assert metadata["result"] == ["ok", %{:status => 200}]

    %{metadata: stored_metadata} =
      Vibe.Telemetry.all()
      |> Enum.find(fn event ->
        get_in(event.metadata, [:request, "host"]) == "auth.openai.com"
      end)

    assert stored_metadata.request["host"] == "auth.openai.com"
    assert stored_metadata["result"] == ["ok", %{:status => 200}]
    refute inspect(stored_metadata) =~ <<1, 2, 3>>
  end

  test "span records start and stop events" do
    assert Vibe.Telemetry.span([:vibe, :plugin, :dispatch], %{event_type: :test}, fn -> :ok end) ==
             :ok

    assert_event(fn event -> event.event == [:vibe, :plugin, :dispatch, :start] end)
    assert_event(fn event -> event.event == [:vibe, :plugin, :dispatch, :stop] end)
  end

  defp assert_event(fun) do
    deadline = System.monotonic_time(:millisecond) + 500
    wait_for_event(fun, deadline)
  end

  defp wait_for_event(fun, deadline) do
    case Enum.find(Vibe.Telemetry.all(), fun) do
      nil ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(10)
          wait_for_event(fun, deadline)
        else
          flunk("telemetry event was not stored")
        end

      event ->
        event
    end
  end
end
