defmodule Exy.PluginManagerTest do
  use ExUnit.Case, async: false

  defmodule StatusWorker do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

    @impl true
    def init(opts) do
      Exy.Plugin.UI.set_status(opts[:session_id], :worker, "worker ready")
      {:ok, opts}
    end
  end

  defmodule PlainWorker do
    use GenServer

    def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
    @impl true
    def init(opts), do: {:ok, opts}
  end

  defmodule BackgroundPlugin do
    use Exy.Plugin

    @impl true
    def init(opts), do: {:ok, %{session_id: Keyword.fetch!(opts, :session_id)}}

    @impl true
    def children(_state, context), do: [{StatusWorker, [session_id: context.session_id]}]
  end

  defmodule PartialFailurePlugin do
    use Exy.Plugin

    @impl true
    def children(_state, _context) do
      [
        {PlainWorker, []},
        {Module.concat(__MODULE__, MissingWorker), []}
      ]
    end
  end

  defmodule EventPlugin do
    use Exy.Plugin

    @impl true
    def handle_event(%{type: :prompt_submitted, text: text}, context, state) do
      Exy.Plugin.UI.set_status(context.session_id, :prompt, "prompt: #{text}")
      {:ok, state}
    end
  end

  test "plugin children run under OTP supervision and can update UI status" do
    session_id = "plugin-ui-session"

    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: session_id,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    assert :ok = Exy.UI.Bus.register(session_id, server)

    assert :ok = Exy.Plugin.Manager.load(BackgroundPlugin, session_id: session_id)
    Process.sleep(50)

    state = Exy.UI.SessionServer.state(server)
    assert state.plugin_statuses == %{"worker" => "worker ready"}

    assert :ok =
             Exy.Plugin.UI.set_widget(session_id, :panel, ["one", "two"],
               placement: :below_editor
             )

    assert :ok = Exy.Plugin.UI.set_working_message(session_id, "indexing")
    assert :ok = Exy.Plugin.UI.set_hidden_thinking_label(session_id, "hidden thoughts")
    assert :ok = Exy.Plugin.UI.set_title(session_id, "Exy Test")

    state = Exy.UI.SessionServer.state(server)
    assert state.plugin_widgets["panel"].content == ["one", "two"]
    assert state.plugin_widgets["panel"].placement == :below_editor
    assert state.working_message == "indexing"
    assert state.hidden_thinking_label == "hidden thoughts"
    assert state.title == "Exy Test"

    assert :ok = Exy.Plugin.UI.clear_widget(session_id, :panel)
    assert :ok = Exy.Plugin.UI.set_status(session_id, :worker, nil)

    state = Exy.UI.SessionServer.state(server)
    assert state.plugin_widgets == %{}
    assert state.plugin_statuses == %{}

    assert :ok = Exy.Plugin.Manager.unload(BackgroundPlugin)
  end

  test "loading an already loaded plugin returns an error" do
    assert :ok = Exy.Plugin.Manager.load(EventPlugin, session_id: "duplicate-plugin")

    assert {:error, :already_loaded} =
             Exy.Plugin.Manager.load(EventPlugin, session_id: "duplicate-plugin")

    assert :ok = Exy.Plugin.Manager.unload(EventPlugin)
  end

  test "partial child startup failure cleans up already started children" do
    before = DynamicSupervisor.which_children(Exy.Plugin.Supervisor)

    assert {:error, _reason} =
             Exy.Plugin.Manager.load(PartialFailurePlugin, session_id: "partial-failure")

    assert DynamicSupervisor.which_children(Exy.Plugin.Supervisor) == before
  end

  test "plugins observe session lifecycle events and update status bar" do
    session_id = "plugin-event-session"

    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: session_id,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    assert :ok = Exy.UI.Bus.register(session_id, server)
    assert :ok = Exy.Plugin.Manager.load(EventPlugin, session_id: session_id)
    assert :ok = Exy.UI.SessionServer.dispatch(server, {:submit_prompt, %{text: "hello"}})
    Process.sleep(50)

    assert Exy.UI.SessionServer.state(server).plugin_statuses["prompt"] == "prompt: hello"
    assert :ok = Exy.Plugin.Manager.unload(EventPlugin)
  end
end
