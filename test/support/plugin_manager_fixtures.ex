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
