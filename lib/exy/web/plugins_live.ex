defmodule Exy.Web.PluginsLive do
  @moduledoc "LiveView for Exy plugin runtime capabilities."
  use Exy.Web, :live_view

  alias Exy.Plugin.Discovery
  alias Exy.Plugin.Manager

  @impl true
  def mount(%{"module" => module_name}, _session, socket) do
    {:ok, assign_plugin(socket, module_name)}
  end

  def mount(_params, _session, socket) do
    {:ok, assign_plugins(socket)}
  end

  @impl true
  def render(%{plugin: plugin} = assigns) when is_map(plugin) do
    ~H"""
    <.app_shell current={:plugins} title={@plugin.short_name} subtitle={@plugin.module}>
      <.link navigate={~p"/plugins"} class="mb-3 inline-flex text-sm text-zinc-500 hover:text-zinc-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">← Plugins</.link>

      <section class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div class="space-y-4">
          <.panel title="Runtime">
            <div class="grid gap-3 sm:grid-cols-3">
              <div class="rounded-md bg-white/[0.035] px-3 py-3">
                <p class="font-mono text-xl text-zinc-100">{length(@plugin.apis)}</p>
                <p class="mt-1 text-xs text-zinc-600">Eval APIs</p>
              </div>
              <div class="rounded-md bg-white/[0.035] px-3 py-3">
                <p class="font-mono text-xl text-zinc-100">{length(@plugin.commands)}</p>
                <p class="mt-1 text-xs text-zinc-600">Commands</p>
              </div>
              <div class="rounded-md bg-white/[0.035] px-3 py-3">
                <p class="font-mono text-xl text-zinc-100">{length(@plugin.actions)}</p>
                <p class="mt-1 text-xs text-zinc-600">Actions</p>
              </div>
            </div>
          </.panel>

          <.panel title="Eval APIs">
            <div :if={@plugin.apis == []} class="text-sm text-zinc-500">No eval APIs exposed.</div>
            <div :if={@plugin.apis != []} class="space-y-3">
              <article :for={api <- @plugin.apis} class="rounded-lg border border-white/8 bg-[#0d0c11]/55 p-3">
                <div class="flex flex-wrap items-center gap-2">
                  <span class="rounded bg-violet-300/10 px-2 py-1 font-mono text-sm text-violet-100">{api.alias}</span>
                  <span class="font-mono text-xs text-zinc-500">{inspect(api.module)}</span>
                </div>
                <p :if={api.description} class="mt-2 text-sm leading-6 text-zinc-300">{api.description}</p>
                <pre :if={api.examples != []} class="mt-2 whitespace-pre-wrap rounded-md bg-[#09080c] p-3 font-mono text-xs leading-5 text-zinc-400">{Enum.join(api.examples, "\n")}</pre>
              </article>
            </div>
          </.panel>
        </div>

        <aside class="space-y-4">
          <.panel title="Details">
            <dl class="space-y-3 text-sm text-zinc-300">
              <div>
                <dt class="text-zinc-500">Module</dt>
                <dd class="mt-1 break-words font-mono text-xs text-zinc-400 [overflow-wrap:anywhere]">{@plugin.module}</dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-zinc-500">Status</dt>
                <dd><.status_badge status={if @plugin.loaded?, do: :ok, else: :idle} /></dd>
              </div>
            </dl>
          </.panel>
        </aside>
      </section>
    </.app_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <.app_shell current={:plugins} title="Plugins" subtitle="Supervised extensions, eval APIs, slash commands, and model-facing capabilities.">
      <section class="overflow-hidden rounded-xl border border-white/10 bg-[#141219]/80">
        <div class="grid gap-px border-b border-white/10 bg-white/10 sm:grid-cols-4">
          <.plugin_metric label="Loaded" value={length(@loaded_plugins)} />
          <.plugin_metric label="Discovered" value={length(@discovered_plugins)} />
          <.plugin_metric label="APIs" value={length(@apis)} />
          <.plugin_metric label="Commands" value={length(@commands)} />
        </div>

        <div :if={@plugins == []} class="p-10 text-center text-sm text-zinc-500">No plugins discovered.</div>
        <div :if={@plugins != []} class="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-3">
          <.link :for={plugin <- @plugins} navigate={~p"/plugins/#{plugin.route_id}"} class="flex min-h-48 flex-col rounded-lg border border-white/10 bg-[#0d0c11]/55 p-4 transition-colors hover:border-white/20 hover:bg-white/[0.025] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-violet-300/70">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-violet-300/75">Plugin</p>
                <h2 class="mt-1 truncate text-base font-semibold text-zinc-50">{plugin.short_name}</h2>
                <p class="mt-1 truncate font-mono text-xs text-zinc-600">{plugin.module}</p>
              </div>
              <.status_badge status={if plugin.loaded?, do: :ok, else: :idle} />
            </div>

            <div class="mt-4 grid grid-cols-3 gap-2 text-center text-xs">
              <div class="rounded-md bg-white/[0.035] px-2 py-2">
                <p class="font-mono text-base text-zinc-100">{length(plugin.apis)}</p>
                <p class="mt-0.5 text-zinc-600">APIs</p>
              </div>
              <div class="rounded-md bg-white/[0.035] px-2 py-2">
                <p class="font-mono text-base text-zinc-100">{length(plugin.commands)}</p>
                <p class="mt-0.5 text-zinc-600">Commands</p>
              </div>
              <div class="rounded-md bg-white/[0.035] px-2 py-2">
                <p class="font-mono text-base text-zinc-100">{length(plugin.actions)}</p>
                <p class="mt-0.5 text-zinc-600">Actions</p>
              </div>
            </div>

            <div :if={plugin.apis != []} class="mt-4 space-y-2">
              <p class="text-[0.62rem] font-semibold uppercase tracking-[0.16em] text-zinc-600">Eval APIs</p>
              <div class="flex flex-wrap gap-1.5">
                <span :for={api <- plugin.apis} class="rounded bg-violet-300/10 px-2 py-1 font-mono text-xs text-violet-100">{api.alias}</span>
              </div>
            </div>
          </.link>
        </div>
      </section>
    </.app_shell>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)

  def plugin_metric(assigns) do
    ~H"""
    <div class="bg-[#141219] px-4 py-3">
      <p class="text-[0.65rem] font-medium uppercase tracking-[0.18em] text-zinc-600">{@label}</p>
      <p class="mt-1 font-mono text-xl text-zinc-100 tabular-nums">{@value}</p>
    </div>
    """
  end

  defp assign_plugins(socket) do
    discovered = Discovery.builtin()
    loaded = safe_manager_call(&Manager.plugins/0, [])
    commands = safe_manager_call(&Manager.commands/0, [])
    apis = safe_manager_call(&Manager.apis/0, [])

    socket
    |> assign(:discovered_plugins, discovered)
    |> assign(:loaded_plugins, loaded)
    |> assign(:commands, commands)
    |> assign(:apis, apis)
    |> assign(:plugins, plugin_cards(discovered, loaded))
  end

  defp assign_plugin(socket, module_name) do
    discovered = Discovery.builtin()
    loaded = safe_manager_call(&Manager.plugins/0, [])

    plugin =
      discovered
      |> plugin_cards(loaded)
      |> Enum.find(&(&1.route_id == module_name))

    assign(socket, :plugin, plugin || missing_plugin(module_name))
  end

  defp plugin_cards(discovered, loaded) do
    loaded_set = MapSet.new(loaded)

    discovered
    |> Enum.map(fn module ->
      %{
        route_id: route_id(module),
        module: inspect(module),
        short_name: module |> Module.split() |> List.last(),
        loaded?: MapSet.member?(loaded_set, module),
        apis: plugin_apis(module),
        commands: plugin_capability(module, :commands),
        actions: plugin_capability(module, :actions)
      }
    end)
  end

  defp plugin_apis(module) do
    module
    |> plugin_capability(:apis)
    |> Enum.map(&Exy.Plugin.API.new/1)
  end

  defp plugin_capability(module, function) do
    if Code.ensure_loaded?(module) and function_exported?(module, function, 1) do
      apply(module, function, [[]])
    else
      []
    end
  rescue
    _reason -> []
  end

  defp route_id(module), do: module |> Module.split() |> Enum.join(".")

  defp missing_plugin(module_name) do
    %{
      route_id: module_name,
      module: module_name,
      short_name: "Plugin not found",
      loaded?: false,
      apis: [],
      commands: [],
      actions: []
    }
  end

  defp safe_manager_call(function, fallback) do
    function.()
  catch
    :exit, _reason -> fallback
  end
end
