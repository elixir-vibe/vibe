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
  slot(:inner_block, required: true)
  slot(:inspector)

  def app_shell(assigns) do
    ~H"""
    <div class="min-h-screen bg-[radial-gradient(circle_at_top_left,rgba(249,115,22,0.16),transparent_34rem),radial-gradient(circle_at_top_right,rgba(124,58,237,0.16),transparent_30rem)] bg-zinc-950 text-zinc-100">
      <header class="sticky top-0 z-30 border-b border-white/10 bg-zinc-950/86 backdrop-blur">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-6 px-6 py-4">
          <div class="flex items-center gap-5">
            <.link navigate={~p"/"} class="group flex items-center gap-3">
              <span class="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-orange-400 to-violet-500 font-black text-zinc-950 shadow-lg shadow-orange-950/30">E</span>
              <span>
                <span class="block text-sm font-semibold tracking-wide text-white">Exy</span>
                <span class="block text-[0.68rem] uppercase tracking-[0.24em] text-orange-200/75">BEAM agent console</span>
              </span>
            </.link>
            <nav class="hidden items-center gap-1 md:flex">
              <.nav_item href={~p"/"} active={@current == :sessions}>Sessions</.nav_item>
              <.nav_item href={~p"/search"} active={@current == :search}>Search</.nav_item>
              <.nav_item href={~p"/runtime"} active={@current == :runtime}>Runtime</.nav_item>
            </nav>
          </div>
          <div class="flex items-center gap-3">
            {render_slot(@actions)}
          </div>
        </div>
      </header>

      <main class="mx-auto grid max-w-7xl gap-6 px-6 py-6 lg:grid-cols-[18rem_minmax(0,1fr)_20rem]">
        <aside :if={@sidebar != []} class="hidden min-w-0 lg:block">
          {render_slot(@sidebar)}
        </aside>

        <section class="min-w-0">
          <div class="mb-6">
            <p class="text-xs font-semibold uppercase tracking-[0.28em] text-orange-300/80">Exy Web</p>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight text-white md:text-4xl">{@title}</h1>
            <p :if={@subtitle} class="mt-2 max-w-3xl text-sm leading-6 text-zinc-400">{@subtitle}</p>
          </div>
          {render_slot(@inner_block)}
        </section>

        <aside :if={@inspector != []} class="hidden min-w-0 xl:block">
          {render_slot(@inspector)}
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
      "rounded-lg px-3 py-2 text-sm transition",
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
    <div class="rounded-2xl border border-white/10 bg-white/[0.035] p-4 shadow-sm">
      <p class="text-xs uppercase tracking-[0.2em] text-zinc-500">{@label}</p>
      <p class={["mt-2 text-2xl font-semibold", @accent]}>{@value}</p>
    </div>
    """
  end

  attr(:status, :any, required: true)

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "rounded-full px-2.5 py-1 text-xs font-medium ring-1",
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
    <.link navigate={~p"/sessions/#{@session.id}"} class="group block rounded-2xl border border-white/10 bg-zinc-900/70 p-4 transition hover:-translate-y-0.5 hover:border-orange-300/70 hover:bg-zinc-900 hover:shadow-xl hover:shadow-orange-950/20">
      <div class="flex items-start justify-between gap-4">
        <div class="min-w-0">
          <p class="truncate text-sm font-semibold text-zinc-100 group-hover:text-orange-100">{@session.first_message || @session.last_message_preview || "Untitled session"}</p>
          <p class="mt-1 truncate text-xs text-zinc-500">{@session.cwd || "unknown workspace"}</p>
        </div>
        <.status_badge status={@session.status} />
      </div>
      <div class="mt-4 flex flex-wrap items-center gap-3 text-xs text-zinc-500">
        <span class="font-mono text-zinc-400">{@session.id}</span>
        <span>{@session.message_count || 0} messages</span>
        <span :if={@session.model}>{@session.model}</span>
      </div>
    </.link>
    """
  end

  attr(:message, :map, required: true)

  def message_card(assigns) do
    ~H"""
    <article class={[
      "rounded-2xl border p-4 shadow-sm",
      if(@message.role == :user,
        do: "ml-auto max-w-[82%] border-orange-300/25 bg-orange-300/12",
        else: "border-white/10 bg-white/[0.035]"
      )
    ]}>
      <div class="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.2em] text-zinc-500">
        <span>{@message.role}</span>
      </div>
      <pre class="whitespace-pre-wrap font-sans text-sm leading-6 text-zinc-100">{message_text(@message)}</pre>
    </article>
    """
  end

  attr(:title, :string, required: true)
  slot(:inner_block, required: true)

  def panel(assigns) do
    ~H"""
    <section class="rounded-2xl border border-white/10 bg-zinc-900/65 p-4">
      <h2 class="mb-3 text-sm font-semibold text-zinc-100">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  defp message_text(%{text: text}) when is_binary(text), do: text
  defp message_text(%{result: %{output: output}}) when is_binary(output), do: output
  defp message_text(%{result: %{"output" => output}}) when is_binary(output), do: output
  defp message_text(%{result: result}), do: inspect(result, pretty: true, limit: 40)
  defp message_text(%{error: error}), do: error
  defp message_text(message), do: inspect(message, pretty: true, limit: 40)
end
