defmodule Vibe.Web.Components.Shell do
  @moduledoc "Application shell and navigation components for Vibe Web."
  use Phoenix.Component

  import PhoenixIconify, only: [icon: 1]

  use Phoenix.VerifiedRoutes,
    endpoint: Vibe.Web.Endpoint,
    router: Vibe.Web.Router,
    statics: Vibe.Web.static_paths()

  attr(:current, :atom, default: :sessions)
  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)
  slot(:sidebar)
  slot(:actions)
  slot(:inner_block, required: true)

  def app_shell(assigns) do
    ~H"""
    <div class="vibe-web-root min-h-screen overflow-x-hidden text-vibe-fg">
      <a href="#main-content" class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-lg focus:bg-vibe-accent focus:px-3 focus:py-2 focus:text-sm focus:font-semibold focus:text-vibe-accent-contrast">
        Skip to content
      </a>

      <header class="sticky top-0 z-30 border-b border-vibe-border/50 bg-vibe-bg/92 backdrop-blur supports-[backdrop-filter]:bg-vibe-bg/78">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <div class="flex min-w-0 items-center gap-4">
            <nav class="hidden items-center gap-1 md:flex" aria-label="Primary">
              <.primary_nav current={@current} />
            </nav>
          </div>

          <div class="flex shrink-0 items-center gap-2">
            <button type="button" data-theme-toggle class="inline-flex size-10 items-center justify-center rounded-lg border border-vibe-border/60 bg-vibe-surface/80 text-vibe-muted transition-colors hover:border-vibe-accent/60 hover:text-vibe-fg-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70" aria-label="Toggle color theme" title="Toggle color theme">
              <.icon name="lucide:sun" class="size-4 dark:hidden" />
              <.icon name="lucide:moon" class="hidden size-4 dark:block" />
            </button>
            {render_slot(@actions)}
          </div>
        </div>

        <nav class="mx-auto flex max-w-7xl gap-1 overflow-x-auto px-4 pb-3 sm:px-6 md:hidden" aria-label="Primary mobile">
          <.primary_nav current={@current} />
        </nav>
      </header>

      <main id="main-content" class={[
        "mx-auto grid max-w-7xl grid-cols-1 gap-4 px-4 py-5 sm:px-6 lg:gap-6 lg:px-8",
        if(@sidebar == [], do: "max-w-5xl", else: "vibe-shell-grid")
      ]}>
        <aside :if={@sidebar != []} class="hidden min-w-0 lg:block">
          <div class="sticky top-24 space-y-4">{render_slot(@sidebar)}</div>
        </aside>

        <section class="min-w-0">
          <div class="mb-4 sm:mb-5">
            <p class="text-[0.68rem] font-semibold uppercase tracking-[0.28em] text-vibe-accent/80">Vibe Web</p>
            <h1 class="mt-2 text-balance text-3xl font-semibold tracking-tight text-vibe-fg-strong sm:text-4xl">{@title}</h1>
            <p :if={@subtitle} class="mt-2 max-w-3xl break-words text-sm leading-6 text-vibe-muted [overflow-wrap:anywhere]">{@subtitle}</p>
          </div>

          <.runtime_alerts alerts={active_runtime_alerts()} />

          {render_slot(@inner_block)}
        </section>
      </main>
    </div>
    """
  end

  defp active_runtime_alerts do
    Vibe.SystemAlarms.active()
  catch
    :exit, _reason -> []
  end

  attr(:alerts, :list, default: [])

  def runtime_alerts(assigns) do
    ~H"""
    <div :if={@alerts != []} class="mb-4 space-y-2">
      <div :for={alert <- @alerts} class={[
        "rounded-xl border p-3 text-sm shadow-lg",
        alert_classes(alert.severity)
      ]}>
        <div class="flex items-start gap-3">
          <.icon name={alert_icon(alert.severity)} class="mt-0.5 size-4 shrink-0" />
          <div class="min-w-0">
            <div class="font-semibold">{alert.title}</div>
            <p class="mt-1 break-words leading-6 opacity-90">{alert.message}</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp alert_classes(:error), do: "border-vibe-error/30 bg-vibe-error/15 text-vibe-error"
  defp alert_classes(:warning), do: "border-vibe-warning/25 bg-vibe-warning/15 text-vibe-warning"
  defp alert_classes(_severity), do: "border-vibe-success/25 bg-vibe-success/10 text-vibe-success"

  defp alert_icon(:error), do: "lucide:circle-x"
  defp alert_icon(:warning), do: "lucide:triangle-alert"
  defp alert_icon(_severity), do: "lucide:info"

  attr(:current, :atom, required: true)

  defp primary_nav(assigns) do
    ~H"""
    <.nav_item href={~p"/"} icon="lucide:messages-square" active={@current == :sessions}>Sessions</.nav_item>
    <.nav_item href={~p"/jobs"} icon="lucide:workflow" active={@current == :jobs}>Jobs</.nav_item>
    <.nav_item href={~p"/memory"} icon="lucide:brain" active={@current == :memory}>Memory</.nav_item>
    <.nav_item href={~p"/gateways"} icon="lucide:radio-tower" active={@current == :gateways}>Gateways</.nav_item>
    <.nav_item href={~p"/storage"} icon="lucide:database" active={@current == :storage}>Storage</.nav_item>
    <.nav_item href={~p"/docs"} icon="lucide:book-open" active={@current == :docs}>Docs</.nav_item>
    <.nav_item href={~p"/runtime"} icon="lucide:activity" active={@current == :runtime}>Runtime</.nav_item>
    <.nav_item href={~p"/plugins"} icon="lucide:plug" active={@current == :plugins}>Plugins</.nav_item>
    <.nav_item href={~p"/skills"} icon="lucide:sparkles" active={@current == :skills}>Skills</.nav_item>
    <.nav_item href={~p"/settings"} icon="lucide:settings" active={@current == :settings}>Settings</.nav_item>
    """
  end

  attr(:href, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:active, :boolean, default: false)
  slot(:inner_block, required: true)

  def nav_item(assigns) do
    ~H"""
    <.link navigate={@href} class={[
      "inline-flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70",
      if(@active, do: "bg-vibe-surface-muted text-vibe-fg-strong", else: "text-vibe-muted hover:bg-vibe-surface-muted/60 hover:text-vibe-fg-strong")
    ]}>
      <.icon name={@icon} class="size-4 shrink-0" />
      <span>{render_slot(@inner_block)}</span>
    </.link>
    """
  end
end
