defmodule Vibe.PluginManagerTest do
  use ExUnit.Case, async: false

  alias Vibe.UI.Widget

  alias Vibe.Test.PluginManagerFixtures.{
    APIPlugin,
    BackgroundPlugin,
    CommandPlugin,
    EventPlugin,
    PartialFailurePlugin
  }

  test "plugin children run under OTP supervision and can update UI status" do
    session_id = "plugin-ui-session"

    {:ok, server} =
      Vibe.Session.start_link(
        session_id: session_id,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    assert :ok = Vibe.UI.Bus.register(session_id, server)

    assert :ok = Vibe.Plugin.Manager.load(BackgroundPlugin, session_id: session_id)
    Process.sleep(50)

    state = Vibe.Session.state(server)
    assert state.plugin_statuses == %{"worker" => "worker ready"}

    assert :ok =
             Vibe.Plugin.UI.set_widget(session_id, :panel, ["one", "two"],
               placement: :below_editor
             )

    assert :ok = Vibe.Plugin.UI.set_working_message(session_id, "indexing")
    assert :ok = Vibe.Plugin.UI.set_hidden_thinking_label(session_id, "hidden thoughts")
    assert :ok = Vibe.Plugin.UI.set_title(session_id, "Vibe Test")

    state = Vibe.Session.state(server)
    assert state.plugin_widgets["panel"].type == :lines
    assert state.plugin_widgets["panel"].props.content == ["one", "two"]
    assert state.plugin_widgets["panel"].placement == :below_editor

    assert :ok =
             Vibe.Plugin.UI.set_progress(session_id, :indexer,
               title: "Indexing",
               current: 12,
               total: 80,
               message: "lib/vibe/session.ex",
               placement: :below_editor
             )

    state = Vibe.Session.state(server)

    assert state.plugin_widgets["indexer"] == %Widget{
             id: "indexer",
             type: :progress,
             placement: :below_editor,
             props: %{
               title: "Indexing",
               current: 12,
               total: 80,
               message: "lib/vibe/session.ex"
             }
           }

    assert state.working_message == "indexing"
    assert state.hidden_thinking_label == "hidden thoughts"
    assert state.title == "Vibe Test"

    assert :ok = Vibe.Plugin.UI.clear_widget(session_id, :panel)
    assert :ok = Vibe.Plugin.UI.clear_widget(session_id, :indexer)
    assert :ok = Vibe.Plugin.UI.set_status(session_id, :worker, nil)

    state = Vibe.Session.state(server)
    assert state.plugin_widgets == %{}
    assert state.plugin_statuses == %{}

    assert :ok = Vibe.Plugin.Manager.unload(BackgroundPlugin)
  end

  test "loading an already loaded plugin returns an error" do
    assert :ok = Vibe.Plugin.Manager.load(EventPlugin, session_id: "duplicate-plugin")

    assert {:error, :already_loaded} =
             Vibe.Plugin.Manager.load(EventPlugin, session_id: "duplicate-plugin")

    assert :ok = Vibe.Plugin.Manager.unload(EventPlugin)
  end

  test "plugins can register slash command modules" do
    assert :ok = Vibe.Plugin.Manager.load(CommandPlugin, session_id: "plugin-command")

    assert Enum.any?(Vibe.UI.SlashCommands.Registry.specs(), &(&1.name == "fixture"))
    assert Vibe.UI.SlashCommands.Registry.find_selector(:missing_selector) == nil

    {:ok, server} = Vibe.Session.start_link(session_id: "plugin-command-session")

    assert :ok =
             Vibe.Session.dispatch(
               server,
               {:slash_command_submitted, %{command: "fixture", args: ""}}
             )

    assert Enum.any?(Vibe.Session.state(server).notifications, &(&1.text == "fixture command"))
    assert :ok = Vibe.Plugin.Manager.unload(CommandPlugin)
  end

  test "plugins can expose eval API modules" do
    assert :ok = Vibe.Plugin.Manager.load(APIPlugin, session_id: "plugin-api")

    api = Enum.find(Vibe.Plugin.Manager.apis(), &(&1.name == :fixture_search))
    assert api
    assert api.name == :fixture_search
    assert api.module == Vibe.Test.PluginManagerFixtures.SearchAPI
    assert api.alias == Search
    assert api.description == "Fixture search API"

    assert :ok = Vibe.Plugin.Manager.unload(APIPlugin)
  end

  test "partial child startup failure cleans up already started children" do
    before = DynamicSupervisor.which_children(Vibe.Plugin.Supervisor)

    assert {:error, _reason} =
             Vibe.Plugin.Manager.load(PartialFailurePlugin, session_id: "partial-failure")

    assert DynamicSupervisor.which_children(Vibe.Plugin.Supervisor) == before
  end

  test "plugins observe session lifecycle events and update status bar" do
    session_id = "plugin-event-session"

    {:ok, server} =
      Vibe.Session.start_link(
        session_id: session_id,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    assert :ok = Vibe.UI.Bus.register(session_id, server)
    assert :ok = Vibe.Plugin.Manager.load(EventPlugin, session_id: session_id)
    assert :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})
    Process.sleep(50)

    assert Vibe.Session.state(server).plugin_statuses["prompt"] == "prompt: hello"
    assert :ok = Vibe.Plugin.Manager.unload(EventPlugin)
  end
end
