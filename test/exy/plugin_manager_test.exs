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

  defmodule BackgroundPlugin do
    use Exy.Plugin

    @impl true
    def init(opts), do: {:ok, %{session_id: Keyword.fetch!(opts, :session_id)}}

    @impl true
    def children(state), do: [{StatusWorker, [session_id: state.session_id]}]
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

    assert :ok = Exy.Plugin.Manager.unload(BackgroundPlugin)
  end
end
