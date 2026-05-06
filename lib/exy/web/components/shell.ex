defmodule Exy.Web.Components.Shell do
  @moduledoc "Application shell and navigation components for Exy Web."
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: Exy.Web.Endpoint,
    router: Exy.Web.Router,
    statics: Exy.Web.static_paths()

  attr(:current, :atom, default: :sessions)
  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)
  slot(:sidebar)
  slot(:actions)
  slot(:mobile_meta)
  slot(:inner_block, required: true)
  slot(:inspector)

  def app_shell(assigns) do
    ~H"""
    <div class="min-h-screen overflow-x-hidden bg-[#0d0c11] bg-[radial-gradient(circle_at_top_left,rgba(249,115,22,0.10),transparent_30rem),radial-gradient(circle_at_top_right,rgba(124,58,237,0.10),transparent_28rem)] text-zinc-100">
      <a href="#main-content" class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:rounded-lg focus:bg-orange-300 focus:px-3 focus:py-2 focus:text-sm focus:font-semibold focus:text-zinc-950">
        Skip to content
      </a>

      <header class="sticky top-0 z-30 border-b border-white/10 bg-[#0d0c11]/92 backdrop-blur supports-[backdrop-filter]:bg-[#0d0c11]/78">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <div class="flex min-w-0 items-center gap-4">
            <nav class="hidden items-center gap-1 md:flex" aria-label="Primary">
              <.nav_item href={~p"/"} active={@current == :sessions}>Sessions</.nav_item>
              <.nav_item href={~p"/jobs"} active={@current == :jobs}>Jobs</.nav_item>
              <.nav_item href={~p"/memory"} active={@current == :memory}>Memory</.nav_item>
              <.nav_item href={~p"/gateways"} active={@current == :gateways}>Gateways</.nav_item>
              <.nav_item href={~p"/storage"} active={@current == :storage}>Storage</.nav_item>
              <.nav_item href={~p"/docs"} active={@current == :docs}>Docs</.nav_item>
              <.nav_item href={~p"/runtime"} active={@current == :runtime}>Runtime</.nav_item>
              <.nav_item href={~p"/plugins"} active={@current == :plugins}>Plugins</.nav_item>
              <.nav_item href={~p"/skills"} active={@current == :skills}>Skills</.nav_item>
              <.nav_item href={~p"/settings"} active={@current == :settings}>Settings</.nav_item>
            </nav>
          </div>

          <div class="flex shrink-0 items-center gap-2">
            {render_slot(@actions)}
          </div>
        </div>

        <nav class="mx-auto flex max-w-7xl gap-1 overflow-x-auto px-4 pb-3 sm:px-6 md:hidden" aria-label="Primary mobile">
          <.nav_item href={~p"/"} active={@current == :sessions}>Sessions</.nav_item>
          <.nav_item href={~p"/jobs"} active={@current == :jobs}>Jobs</.nav_item>
          <.nav_item href={~p"/memory"} active={@current == :memory}>Memory</.nav_item>
          <.nav_item href={~p"/gateways"} active={@current == :gateways}>Gateways</.nav_item>
          <.nav_item href={~p"/storage"} active={@current == :storage}>Storage</.nav_item>
          <.nav_item href={~p"/docs"} active={@current == :docs}>Docs</.nav_item>
          <.nav_item href={~p"/runtime"} active={@current == :runtime}>Runtime</.nav_item>
          <.nav_item href={~p"/plugins"} active={@current == :plugins}>Plugins</.nav_item>
          <.nav_item href={~p"/skills"} active={@current == :skills}>Skills</.nav_item>
          <.nav_item href={~p"/settings"} active={@current == :settings}>Settings</.nav_item>
        </nav>
      </header>

      <main id="main-content" class={[
        "mx-auto grid max-w-7xl grid-cols-1 gap-4 px-4 py-5 sm:px-6 lg:gap-6 lg:px-8",
        if(@sidebar == [] and @inspector == [], do: "max-w-5xl", else: "exy-shell-grid")
      ]}>
        <aside :if={@sidebar != []} class="hidden min-w-0 lg:block">
          <div class="sticky top-24 space-y-4">{render_slot(@sidebar)}</div>
        </aside>

        <section class="min-w-0">
          <div class="mb-4 sm:mb-5">
            <p class="text-[0.68rem] font-semibold uppercase tracking-[0.28em] text-orange-300/80">Exy Web</p>
            <h1 class="mt-2 text-balance text-3xl font-semibold tracking-tight text-white sm:text-4xl">{@title}</h1>
            <p :if={@subtitle} class="mt-2 max-w-3xl break-words text-sm leading-6 text-zinc-400 [overflow-wrap:anywhere]">{@subtitle}</p>
          </div>

          <div :if={@mobile_meta != []} class="mb-4 lg:hidden">
            {render_slot(@mobile_meta)}
          </div>

          <.runtime_alerts alerts={active_runtime_alerts()} />

          {render_slot(@inner_block)}
        </section>

        <aside :if={@inspector != []} class="hidden min-w-0 xl:block">
          <div class="sticky top-24 space-y-4">{render_slot(@inspector)}</div>
        </aside>
      </main>
    </div>
    """
  end

  defp active_runtime_alerts do
    Exy.SystemAlarms.active()
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
          <span class="mt-0.5">{alert_icon(alert.severity)}</span>
          <div class="min-w-0">
            <div class="font-semibold">{alert.title}</div>
            <p class="mt-1 break-words leading-6 opacity-90">{alert.message}</p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp alert_classes(:error), do: "border-red-400/30 bg-red-950/35 text-red-100"
  defp alert_classes(:warning), do: "border-yellow-400/25 bg-yellow-950/30 text-yellow-100"
  defp alert_classes(_severity), do: "border-sky-400/25 bg-sky-950/25 text-sky-100"

  defp alert_icon(:error), do: "✕"
  defp alert_icon(:warning), do: "⚠"
  defp alert_icon(_severity), do: "•"

  attr(:href, :string, required: true)
  attr(:active, :boolean, default: false)
  slot(:inner_block, required: true)

  def nav_item(assigns) do
    ~H"""
    <.link navigate={@href} class={[
      "shrink-0 rounded-lg px-3 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70",
      if(@active, do: "bg-white/10 text-white", else: "text-zinc-400 hover:bg-white/5 hover:text-zinc-100")
    ]}>
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
