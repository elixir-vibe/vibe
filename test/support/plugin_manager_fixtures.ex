defmodule Exy.Test.PluginManagerFixtures.StatusWorker do
  @moduledoc false

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    Exy.Plugin.UI.set_status(opts[:session_id], :worker, "worker ready")
    {:ok, opts}
  end
end

defmodule Exy.Test.PluginManagerFixtures.PlainWorker do
  @moduledoc false

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts), do: {:ok, opts}
end

defmodule Exy.Test.PluginManagerFixtures.BackgroundPlugin do
  @moduledoc false

  use Exy.Plugin

  alias Exy.Test.PluginManagerFixtures.StatusWorker

  @impl true
  def init(opts), do: {:ok, %{session_id: Keyword.fetch!(opts, :session_id)}}

  @impl true
  def children(_state, context), do: [{StatusWorker, [session_id: context.session_id]}]
end

defmodule Exy.Test.PluginManagerFixtures.PartialFailurePlugin do
  @moduledoc false

  use Exy.Plugin

  alias Exy.Test.PluginManagerFixtures.PlainWorker

  @impl true
  def children(_state, _context) do
    [
      {PlainWorker, []},
      {Module.concat(__MODULE__, MissingWorker), []}
    ]
  end
end

defmodule Exy.Test.PluginManagerFixtures.EventPlugin do
  @moduledoc false

  use Exy.Plugin

  @impl true
  def handle_event(%{type: :prompt_submitted, text: text}, context, state) do
    Exy.Plugin.UI.set_status(context.session_id, :prompt, "prompt: #{text}")
    {:ok, state}
  end
end

defmodule Exy.Test.PluginManagerFixtures.PluginCommand do
  @moduledoc false

  @behaviour Exy.UI.SlashCommands.Command

  @impl true
  def spec, do: %{name: "fixture", description: "Fixture plugin command"}

  @impl true
  def run(_args, ui_state) do
    {:events,
     [
       Exy.UI.Event.new(:notification_added, ui_state.session_id, %{
         level: :info,
         text: "fixture command"
       })
     ]}
  end
end

defmodule Exy.Test.PluginManagerFixtures.CommandPlugin do
  @moduledoc false

  use Exy.Plugin

  alias Exy.Test.PluginManagerFixtures.PluginCommand

  @impl true
  def commands(_state), do: [PluginCommand]
end

defmodule Exy.Test.PluginManagerFixtures.SearchAPI do
  @moduledoc false

  def remember(value), do: {:remembered, value}
end

defmodule Exy.Test.PluginManagerFixtures.APIPlugin do
  @moduledoc false

  use Exy.Plugin

  api(
    name: :fixture_search,
    module: Exy.Test.PluginManagerFixtures.SearchAPI,
    alias: Search,
    description: "Fixture search API",
    examples: ["Search.remember(query)"]
  )
end
