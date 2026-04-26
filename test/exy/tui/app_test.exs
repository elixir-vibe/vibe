defmodule Exy.TUI.AppTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.App

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
    Process.sleep(50)

    snapshot = App.snapshot(app)
    assert snapshot.editor.text == ""
    assert Enum.any?(snapshot.ui.messages, &(&1.role == :assistant))
    assert snapshot.width == 80
  end

  test "routes slash commands into semantic UI events" do
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/model openai_codex:gpt-5.5"})
    :ok = App.key(app, :submit)

    assert Enum.any?(App.snapshot(app).ui.events, fn event ->
             event.type == :slash_command_submitted and event.data.command == "model"
           end)

    assert App.snapshot(app).ui.selector.kind == :model_selector
    :ok = App.key(app, :cancel)
    assert App.snapshot(app).ui.selector == nil
  end

  test "new slash command switches to a fresh session" do
    {:ok, app} = App.start_link()
    old_session = App.snapshot(app).ui.session_id

    :ok = App.key(app, {:insert, "/new"})
    :ok = App.key(app, :submit)
    Process.sleep(20)

    assert App.snapshot(app).ui.session_id != old_session
  end

  test "attach slash command switches to an existing session" do
    {:ok, target} = Exy.Session.start(session_id: "attach-target", persist?: false)
    {:ok, app} = App.start_link()

    :ok = App.key(app, {:insert, "/attach attach-target"})
    :ok = App.key(app, :submit)
    Process.sleep(20)

    assert App.snapshot(app).ui.session_id == Exy.Session.state(target).session_id
  end

  test "migrates local startup session to server session when server becomes available" do
    parent = self()

    migration_fun = fn current ->
      {:ok, remote} =
        Exy.Session.start_link(
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
        server_migration_fun: migration_fun,
        persist?: false
      )

    assert_receive {:migrated, "async-migration-session"}, 1_000
    Process.sleep(20)

    snapshot = App.snapshot(app)
    assert snapshot.ui.session_id == "async-migration-session"
    assert Enum.any?(snapshot.ui.notifications, &(&1.text == "attached to background server"))
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

  test "tracks resize" do
    {:ok, app} = App.start_link()
    :ok = App.resize(app, 120, 40)
    assert %{width: 120, height: 40} = App.snapshot(app)
  end
end
