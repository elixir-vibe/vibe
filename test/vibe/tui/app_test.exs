defmodule Vibe.TUI.AppTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.App

  @long_prompt_sleep_ms 5_000
  @migration_assert_timeout_ms 5_000

  test "coordinates editor submit and ui events" do
    ask = fn text, opts ->
      if opts[:on_result] do
        opts[:on_result].("streamed ")
        opts[:on_result].(text)
      end

      {:ok, %{message: %{content: [%{type: :text, text: "streamed " <> text}]}}}
    end

    {:ok, app} = App.start_link(ask_fun: ask, width: 80, height: 20)

    :ok = App.key(app, {:insert, "hello"})
    :ok = App.key(app, :submit)

    snapshot = App.snapshot(app)
    assert snapshot.editor.text == ""

    snapshot =
      wait_until(app, fn snapshot -> Enum.any?(snapshot.ui.messages, &(&1.role == :assistant)) end)

    assert Enum.any?(snapshot.ui.messages, &(&1.role == :assistant))
    assert snapshot.width == 80
  end

  test "routes slash commands into semantic UI events" do
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/model"})
    :ok = App.key(app, :submit)

    snapshot =
      wait_until(app, fn snapshot ->
        not is_nil(snapshot.ui.selector) and
          Enum.any?(snapshot.ui.events, fn event ->
            event.type == :slash_command_submitted and event.data.command == "model"
          end)
      end)

    assert snapshot.ui.selector.kind == :model_selector
    :ok = App.key(app, :cancel)
    assert App.snapshot(app).ui.selector == nil
  end

  test "clear slash command asks for confirmation" do
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "hello"})
    :ok = App.key(app, :submit)
    assert wait_until(app, &Enum.any?(&1.ui.messages, fn message -> message.role == :user end))

    :ok = App.key(app, {:insert, "/clear"})
    :ok = App.key(app, :submit)

    snapshot = wait_until(app, &match?(%{kind: :clear_session_confirmation}, &1.ui.selector))
    assert snapshot.ui.selector.title == "Clear session?"
    assert snapshot.ui.selector.message == "This will delete all messages in the current session."
    assert snapshot.ui.messages != []

    :ok = App.key(app, :down)
    :ok = App.key(app, :submit)
    snapshot = App.snapshot(app)
    assert snapshot.ui.selector == nil
    assert snapshot.ui.messages != []

    :ok = App.key(app, {:insert, "/clear"})
    :ok = App.key(app, :submit)
    assert wait_until(app, &match?(%{kind: :clear_session_confirmation}, &1.ui.selector))

    :ok = App.key(app, :submit)
    snapshot = wait_until(app, &(&1.ui.selector == nil and &1.ui.messages == []))
    assert snapshot.ui.messages == []
  end

  test "new slash command switches to a fresh session" do
    {:ok, app} = App.start_link()
    old_session = App.snapshot(app).ui.session_id

    :ok = App.key(app, {:insert, "/new"})
    :ok = App.key(app, :submit)

    snapshot = wait_until(app, &(&1.ui.session_id != old_session))
    assert snapshot.ui.session_id != old_session
  end

  test "attach slash command switches to an existing session" do
    {:ok, target} = Vibe.Session.start(session_id: "attach-target", persist?: false)
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/attach attach-target"})
    :ok = App.key(app, :submit)

    snapshot = wait_until(app, &(&1.ui.session_id == Vibe.Session.state(target).session_id))
    assert snapshot.ui.session_id == Vibe.Session.state(target).session_id
  end

  test "migrates local startup session to server session when server becomes available" do
    parent = self()

    migration_fun = fn current ->
      {:ok, remote} =
        Vibe.Session.start_link(
          session_id: current.session_id,
          cwd: current.cwd,
          model: current.model,
          persist?: false
        )

      send(parent, {:migrated, current.session_id})
      {:ok, :remote_node, current.session_id, remote}
    end

    {:ok, app} =
      App.start_link(
        session_id: "async-migration-session",
        start_server_async: true,
        server_migration_delay_ms: 0,
        server_migration_fun: migration_fun,
        persist?: false
      )

    assert_receive {:migrated, "async-migration-session"}, @migration_assert_timeout_ms
    Process.sleep(20)

    snapshot = App.snapshot(app)
    assert snapshot.ui.session_id == "async-migration-session"
    assert Enum.any?(snapshot.ui.notifications, &(&1.text == "attached to background server"))
  end

  test "does not migrate after a prompt is submitted" do
    parent = self()

    migration_fun = fn current ->
      send(parent, {:migration_attempted, current.session_id})
      {:error, :should_not_migrate_after_prompt}
    end

    {:ok, app} =
      App.start_link(
        session_id: "busy-local-session",
        server_migration_fun: migration_fun,
        persist?: false,
        ask_fun: fn _text, _opts ->
          Process.sleep(@long_prompt_sleep_ms)
          {:ok, "done"}
        end
      )

    :ok = App.key(app, {:insert, "fix this"})
    :ok = App.key(app, :submit)

    snapshot = wait_until(app, &(&1.ui.status == :working))
    assert snapshot.ui.session_id == "busy-local-session"

    send(app, :server_migration_tick)
    App.snapshot(app)
    refute_received {:migration_attempted, "busy-local-session"}
  end

  test "offers generic slash command autocomplete" do
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/se"})
    assert %{autocomplete: %{items: [%{value: "/sessions"} | _]}} = App.snapshot(app)

    :ok = App.key(app, :tab)
    snapshot = App.snapshot(app)

    assert snapshot.editor.text == "/sessions "
    assert snapshot.autocomplete == nil
  end

  test "escape cancels a running prompt" do
    parent = self()

    ask = fn _text, _opts ->
      send(parent, :ask_started)
      Process.sleep(@long_prompt_sleep_ms)
      {:ok, "too late"}
    end

    {:ok, app} = App.start_link(ask_fun: ask)

    :ok = App.key(app, {:insert, "slow"})
    :ok = App.key(app, :submit)
    assert_receive :ask_started, 10_000
    assert wait_until(app, &(&1.ui.status == :working))

    :ok = App.key(app, :cancel)

    snapshot = wait_until(app, &(&1.ui.status == :idle))
    assert Enum.any?(snapshot.ui.events, &(&1.type == :assistant_aborted))
    assert Enum.any?(snapshot.ui.messages, &(&1.role == :assistant and &1.text == "Cancelled."))
    assert snapshot.ui.notifications == []
  end

  test "escape closes autocomplete without cancelling the session" do
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/se"})
    assert %{autocomplete: %{items: [_ | _]}} = App.snapshot(app)

    :ok = App.key(app, :cancel)
    snapshot = App.snapshot(app)

    assert snapshot.autocomplete == nil
    assert snapshot.editor.text == "/se"
    refute Enum.any?(snapshot.ui.notifications, &(&1.text == "cancelled"))
  end

  test "submit applies selected slash command from autocomplete" do
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/mo"})
    assert %{autocomplete: %{items: [%{value: "/model"} | _]}} = App.snapshot(app)

    :ok = App.key(app, :submit)

    snapshot =
      wait_until(app, fn snapshot ->
        snapshot.editor.text == "" and
          not is_nil(snapshot.ui.selector) and
          Enum.any?(snapshot.ui.events, fn event ->
            event.type == :slash_command_submitted and event.data.command == "model"
          end)
      end)

    assert snapshot.autocomplete == nil
    assert snapshot.ui.selector.kind == :model_selector
    refute Enum.any?(snapshot.ui.notifications, &String.contains?(&1.text, "unknown command"))
  end

  test "tracks resize" do
    {:ok, app} = App.start_link()
    :ok = App.resize(app, 120, 40)
    assert %{width: 120, height: 40} = App.snapshot(app)
  end

  defp wait_until(
         app,
         fun,
         deadline \\ System.monotonic_time(:millisecond) + @migration_assert_timeout_ms
       ) do
    snapshot = App.snapshot(app)

    cond do
      fun.(snapshot) ->
        snapshot

      System.monotonic_time(:millisecond) < deadline ->
        Process.sleep(10)
        wait_until(app, fun, deadline)

      true ->
        snapshot
    end
  end
end
