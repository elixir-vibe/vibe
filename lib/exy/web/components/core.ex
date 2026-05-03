defmodule Exy.Web.Components.Core do
  @moduledoc "Small reusable UI primitives for Exy Web."
  use Phoenix.Component

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
end
