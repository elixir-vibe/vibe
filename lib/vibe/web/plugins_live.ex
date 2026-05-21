defmodule Vibe.Web.PluginsLive do
  @moduledoc "LiveView for Vibe plugin runtime capabilities."
  use Vibe.Web, :live_view

  alias Vibe.Plugin.Discovery
  alias Vibe.Plugin.Manager

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
      <.link navigate={~p"/plugins"} class="mb-3 inline-flex text-sm text-vibe-dim hover:text-vibe-fg-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70">← Plugins</.link>

      <section class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <div class="space-y-4">
          <.panel title="Runtime">
            <div class="grid gap-3 sm:grid-cols-3">
              <div class="rounded-md bg-vibe-surface-muted/35 px-3 py-3">
                <p class="font-mono text-xl text-vibe-fg-strong">{length(@plugin.apis)}</p>
                <p class="mt-1 text-xs text-vibe-dim">Eval APIs</p>
              </div>
              <div class="rounded-md bg-vibe-surface-muted/35 px-3 py-3">
                <p class="font-mono text-xl text-vibe-fg-strong">{length(@plugin.commands)}</p>
                <p class="mt-1 text-xs text-vibe-dim">Commands</p>
              </div>
              <div class="rounded-md bg-vibe-surface-muted/35 px-3 py-3">
                <p class="font-mono text-xl text-vibe-fg-strong">{length(@plugin.actions)}</p>
                <p class="mt-1 text-xs text-vibe-dim">Actions</p>
              </div>
            </div>
          </.panel>

          <.panel title="Plugin UI">
            <div :if={@plugin.ui_document.sections == []} class="text-sm text-vibe-dim">No plugin-owned presentation exposed.</div>
            <div :if={@plugin.ui_document.sections != []} class="space-y-3">
              <article :for={section <- @plugin.ui_document.sections} class="rounded-lg border border-vibe-border/40 bg-vibe-bg/55 p-4">
                <h2 class="text-base font-semibold text-vibe-fg-strong">{section.title}</h2>
                <p :if={section.description} class="mt-1 text-sm leading-6 text-vibe-muted">{section.description}</p>
                <div class="mt-3 space-y-2">
                  <.plugin_ui_widget :for={widget <- section.widgets} widget={widget} />
                </div>
              </article>
            </div>
          </.panel>

          <.panel title="Eval APIs">
            <.api_sections apis={@plugin.apis} />
          </.panel>
        </div>

        <aside class="space-y-4">
          <.panel title="Details">
            <dl class="space-y-3 text-sm text-vibe-fg">
              <div>
                <dt class="text-vibe-dim">Module</dt>
                <dd class="mt-1 break-words font-mono text-xs text-vibe-muted [overflow-wrap:anywhere]">{@plugin.module}</dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-vibe-dim">Status</dt>
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
      <section class="overflow-hidden rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80">
        <div class="grid gap-px border-b border-vibe-border/50 bg-vibe-surface-muted sm:grid-cols-4">
          <.metric_tile label="Loaded" value={length(@loaded_plugins)} />
          <.metric_tile label="Discovered" value={length(@discovered_plugins)} />
          <.metric_tile label="APIs" value={length(@apis)} />
          <.metric_tile label="Commands" value={length(@commands)} />
        </div>

        <div :if={@plugins == []} class="p-10 text-center text-sm text-vibe-dim">No plugins discovered.</div>
        <div :if={@plugins != []} class="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-3">
          <.link :for={plugin <- @plugins} navigate={~p"/plugins/#{plugin.route_id}"} class="flex min-h-48 flex-col rounded-lg border border-vibe-border/50 bg-vibe-bg/55 p-4 transition-colors hover:border-vibe-border hover:bg-vibe-surface-muted/35 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-vibe-accent/75">Plugin</p>
                <h2 class="mt-1 truncate text-base font-semibold text-vibe-fg-strong">{plugin.short_name}</h2>
                <p class="mt-1 truncate font-mono text-xs text-vibe-dim">{plugin.module}</p>
              </div>
              <.status_badge status={if plugin.loaded?, do: :ok, else: :idle} />
            </div>

            <div class="mt-4 grid grid-cols-3 gap-2 text-center text-xs">
              <div class="rounded-md bg-vibe-surface-muted/35 px-2 py-2">
                <p class="font-mono text-base text-vibe-fg-strong">{length(plugin.apis)}</p>
                <p class="mt-0.5 text-vibe-dim">APIs</p>
              </div>
              <div class="rounded-md bg-vibe-surface-muted/35 px-2 py-2">
                <p class="font-mono text-base text-vibe-fg-strong">{length(plugin.commands)}</p>
                <p class="mt-0.5 text-vibe-dim">Commands</p>
              </div>
              <div class="rounded-md bg-vibe-surface-muted/35 px-2 py-2">
                <p class="font-mono text-base text-vibe-fg-strong">{length(plugin.actions)}</p>
                <p class="mt-0.5 text-vibe-dim">Actions</p>
              </div>
            </div>

            <div :if={plugin.apis != []} class="mt-4 space-y-2">
              <p class="text-[0.62rem] font-semibold uppercase tracking-[0.16em] text-vibe-dim">Eval APIs</p>
              <div class="flex flex-wrap gap-1.5">
                <span :for={api <- plugin.apis} class="rounded bg-vibe-accent/10 px-2 py-1 font-mono text-xs text-vibe-accent-strong">{api.alias}</span>
              </div>
            </div>
          </.link>
        </div>
      </section>
    </.app_shell>
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
        actions: plugin_capability(module, :actions),
        ui_document:
          safe_manager_call(
            fn -> Manager.ui_document(module) end,
            Vibe.Presentation.Document.empty()
          )
      }
    end)
  end

  defp plugin_apis(module) do
    module
    |> plugin_capability(:apis)
    |> Enum.map(&Vibe.Plugin.API.new/1)
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
      actions: [],
      ui_document: Vibe.Presentation.Document.empty()
    }
  end

  defp safe_manager_call(function, fallback) do
    function.()
  catch
    :exit, _reason -> fallback
  end
end
