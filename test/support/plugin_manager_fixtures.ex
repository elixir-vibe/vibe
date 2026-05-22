defmodule Vibe.Test.PluginManagerFixtures.StatusWorker do
  @moduledoc false

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    Vibe.Plugin.UI.set_status(opts[:session_id], :worker, "worker ready")
    {:ok, opts}
  end
end

defmodule Vibe.Test.PluginManagerFixtures.PlainWorker do
  @moduledoc false

  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts), do: {:ok, opts}
end

defmodule Vibe.Test.PluginManagerFixtures.BackgroundPlugin do
  @moduledoc false

  use Vibe.Plugin

  alias Vibe.Test.PluginManagerFixtures.StatusWorker

  @impl true
  def init(opts), do: {:ok, %{session_id: Keyword.fetch!(opts, :session_id)}}

  @impl true
  def children(_state, context), do: [{StatusWorker, [session_id: context.session_id]}]
end

defmodule Vibe.Test.PluginManagerFixtures.PartialFailurePlugin do
  @moduledoc false

  use Vibe.Plugin

  alias Vibe.Test.PluginManagerFixtures.PlainWorker

  @impl true
  def children(_state, _context) do
    [
      {PlainWorker, []},
      {Module.concat(__MODULE__, MissingWorker), []}
    ]
  end
end

defmodule Vibe.Test.PluginManagerFixtures.EventPlugin do
  @moduledoc false

  use Vibe.Plugin

  @impl true
  def handle_event(%{type: :prompt_submitted, text: text}, context, state) do
    Vibe.Plugin.UI.set_status(context.session_id, :prompt, "prompt: #{text}")
    {:ok, state}
  end
end

defmodule Vibe.Test.PluginManagerFixtures.PluginCommand do
  @moduledoc false

  @behaviour Vibe.Session.Command.Command

  @impl true
  def spec, do: %{name: "fixture", description: "Fixture plugin command"}

  @impl true
  def run(_args, state) do
    {:events,
     [
       Vibe.Event.new(:notification_added, state.session_id, %{
         level: :info,
         text: "fixture command"
       })
     ]}
  end
end

defmodule Vibe.Test.PluginManagerFixtures.CommandPlugin do
  @moduledoc false

  use Vibe.Plugin

  alias Vibe.Test.PluginManagerFixtures.PluginCommand

  @impl true
  def commands(_state), do: [PluginCommand]
end

defmodule Vibe.Test.PluginManagerFixtures.SearchAPI do
  @moduledoc false

  def remember(value), do: {:remembered, value}
end

defmodule Vibe.Test.PluginManagerFixtures.APIPlugin do
  @moduledoc false

  use Vibe.Plugin

  api(
    name: :fixture_search,
    module: Vibe.Test.PluginManagerFixtures.SearchAPI,
    alias: Search,
    description: "Fixture search API",
    examples: ["Search.remember(query)"]
  )
end

defmodule Vibe.Test.PluginManagerFixtures.ToolPipelinePluginA do
  @moduledoc false

  use Vibe.Plugin

  @impl true
  def tool_call(call, _context, state) do
    {:ok, Map.update(call, :steps, [:a], &(&1 ++ [:a])), state}
  end

  @impl true
  def tool_result(result, _context, state) do
    {:ok, Map.update(result, :steps, [:a], &(&1 ++ [:a])), state}
  end

  @impl true
  def context(messages, _context, state) do
    {:ok, messages ++ [%{role: :system, text: "a"}], state}
  end
end

defmodule Vibe.Test.PluginManagerFixtures.ToolPipelinePluginB do
  @moduledoc false

  use Vibe.Plugin

  @impl true
  def tool_call(call, _context, state) do
    {:ok, Map.update(call, :steps, [:b], &(&1 ++ [:b])), state}
  end

  @impl true
  def tool_result(result, _context, state) do
    {:ok, Map.update(result, :steps, [:b], &(&1 ++ [:b])), state}
  end

  @impl true
  def context(messages, _context, state) do
    {:ok, messages ++ [%{role: :system, text: "b"}], state}
  end
end

defmodule Vibe.Test.PluginManagerFixtures.ToolBlockPlugin do
  @moduledoc false

  use Vibe.Plugin

  @impl true
  def tool_call(_call, _context, state), do: {:block, "blocked by fixture", state}
end
