defmodule Exy.Web.Components do
  @moduledoc """
  Shared Phoenix components for the Exy web console.
  """
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
        <div class="mx-auto flex max-w-[1500px] items-center justify-between gap-4 px-4 py-3 sm:px-6 lg:px-8">
          <div class="flex min-w-0 items-center gap-4">
            <.link navigate={~p"/"} class="group flex min-w-0 items-center gap-3 rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">
              <span class="grid h-10 w-10 shrink-0 place-items-center rounded-lg bg-gradient-to-br from-orange-300 to-violet-500 font-black text-zinc-950 shadow-lg shadow-orange-950/20">E</span>
              <span class="min-w-0">
                <span class="block text-sm font-semibold tracking-wide text-white">Exy</span>
                <span class="block truncate text-[0.66rem] uppercase tracking-[0.24em] text-orange-200/75">BEAM agent console</span>
              </span>
            </.link>

            <nav class="hidden items-center gap-1 md:flex" aria-label="Primary">
              <.nav_item href={~p"/"} active={@current == :sessions}>Sessions</.nav_item>
              <.nav_item href={~p"/search"} active={@current == :search}>Search</.nav_item>
              <.nav_item href={~p"/runtime"} active={@current == :runtime}>Runtime</.nav_item>
            </nav>
          </div>

          <div class="flex shrink-0 items-center gap-2">
            {render_slot(@actions)}
          </div>
        </div>

        <nav class="mx-auto flex max-w-[1500px] gap-1 overflow-x-auto px-4 pb-3 sm:px-6 md:hidden" aria-label="Primary mobile">
          <.nav_item href={~p"/"} active={@current == :sessions}>Sessions</.nav_item>
          <.nav_item href={~p"/search"} active={@current == :search}>Search</.nav_item>
          <.nav_item href={~p"/runtime"} active={@current == :runtime}>Runtime</.nav_item>
        </nav>
      </header>

      <main id="main-content" class="exy-shell-grid mx-auto grid max-w-[1500px] grid-cols-1 gap-4 px-4 py-5 sm:px-6 lg:gap-6 lg:px-8">
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

          {render_slot(@inner_block)}
        </section>

        <aside :if={@inspector != []} class="hidden min-w-0 xl:block">
          <div class="sticky top-24 space-y-4">{render_slot(@inspector)}</div>
        </aside>
      </main>
    </div>
    """
  end

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

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)
  attr(:accent, :string, default: "text-orange-300")

  def stat_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-white/10 bg-[#17151d]/80 p-4 shadow-sm">
      <p class="text-[0.68rem] uppercase tracking-[0.18em] text-zinc-500">{@label}</p>
      <p class={["mt-2 text-2xl font-semibold tabular-nums", @accent]}>{@value}</p>
    </div>
    """
  end

  attr(:status, :any, required: true)

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-medium ring-1",
      case to_string(@status) do
        "working" -> "bg-orange-400/10 text-orange-200 ring-orange-400/30"
        "error" -> "bg-red-400/10 text-red-200 ring-red-400/30"
        _ -> "bg-emerald-400/10 text-emerald-200 ring-emerald-400/30"
      end
    ]}>{@status}</span>
    """
  end

  attr(:session, :map, required: true)

  def session_card(assigns) do
    ~H"""
    <.link navigate={~p"/sessions/#{@session.id}"} class="group block rounded-xl border border-white/10 bg-[#17151d]/82 px-4 py-3 transition-colors hover:border-orange-300/50 hover:bg-[#1d1a24] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">
      <div class="flex min-w-0 items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-semibold text-zinc-100 group-hover:text-orange-100">{session_title(@session)}</p>
          <p class="mt-1 truncate text-xs text-zinc-500">{@session.cwd || "unknown workspace"}</p>
        </div>
        <.status_badge status={@session.status} />
      </div>
      <div class="mt-3 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 text-xs text-zinc-500">
        <span class="max-w-full truncate font-mono text-zinc-400">{@session.id}</span>
        <span>{@session.message_count || 0} messages</span>
        <span :if={@session.model} class="truncate">{@session.model}</span>
      </div>
    </.link>
    """
  end

  attr(:message, :map, required: true)

  def message_card(assigns) do
    ~H"""
    <article class={[
      "max-w-full rounded-xl border px-4 py-3 shadow-sm sm:px-5 sm:py-4",
      if(@message.role == :user,
        do: "border-orange-300/25 bg-orange-300/10 sm:ml-auto sm:max-w-[88%]",
        else: "border-white/10 bg-[#17151d]/82"
      )
    ]}>
      <div class="mb-2 flex items-center gap-2 text-[0.68rem] font-semibold uppercase tracking-[0.22em] text-zinc-500">
        <span>{@message.role}</span>
      </div>
      <div class="whitespace-pre-wrap break-words font-sans text-sm leading-6 text-zinc-100 [overflow-wrap:anywhere]">{message_text(@message)}</div>
    </article>
    """
  end

  attr(:title, :string, required: true)
  slot(:inner_block, required: true)

  def panel(assigns) do
    ~H"""
    <section class="rounded-xl border border-white/10 bg-[#17151d]/78 p-4 shadow-sm">
      <h2 class="mb-3 text-sm font-semibold text-zinc-100">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  defp session_title(session) do
    session.first_message || session.last_message_preview || "Untitled session"
  end

  defp message_text(%{text: text}) when is_binary(text), do: text
  defp message_text(%{result: %{output: output}}) when is_binary(output), do: output
  defp message_text(%{result: %{"output" => output}}) when is_binary(output), do: output
  defp message_text(%{result: result}), do: inspect(result, pretty: true, limit: 40)
  defp message_text(%{error: error}), do: error
  defp message_text(message), do: inspect(message, pretty: true, limit: 40)
end
