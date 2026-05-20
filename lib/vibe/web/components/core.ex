defmodule Vibe.Web.Components.Core do
  @moduledoc "Small reusable UI primitives for Vibe Web."
  use Phoenix.Component

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)

  def metric_tile(assigns) do
    ~H"""
    <div class="bg-vibe-bg-soft px-4 py-3">
      <p class="text-[0.65rem] font-medium uppercase tracking-[0.18em] text-vibe-dim">{@label}</p>
      <p class="mt-1 font-mono text-xl text-vibe-fg-strong tabular-nums">{@value}</p>
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)
  attr(:detail, :any, default: nil)
  attr(:detail_class, :string, default: "font-mono text-vibe-dim")

  def info_tile(assigns) do
    ~H"""
    <div class="rounded-xl border border-vibe-border/50 bg-vibe-surface-muted/30 p-3">
      <p class="text-[0.65rem] uppercase tracking-[0.18em] text-vibe-dim">{@label}</p>
      <p class="mt-2 font-medium text-vibe-fg-strong">{@value}</p>
      <p :if={@detail not in [nil, ""]} class={["mt-1 text-xs", @detail_class]}>{@detail}</p>
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)
  attr(:accent, :string, default: "text-vibe-accent")

  def stat_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-vibe-border/50 bg-vibe-surface/80 p-4 shadow-sm">
      <p class="text-[0.68rem] uppercase tracking-[0.18em] text-vibe-dim">{@label}</p>
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
        "working" -> "bg-vibe-accent/10 text-vibe-accent-strong ring-vibe-accent/30"
        "error" -> "bg-vibe-error/10 text-vibe-error ring-vibe-error/30"
        _ -> "bg-vibe-success/10 text-vibe-success ring-vibe-success/30"
      end
    ]}>{@status}</span>
    """
  end

  attr(:title, :string, required: true)
  slot(:inner_block, required: true)

  def panel(assigns) do
    ~H"""
    <section class="rounded-xl border border-vibe-border/50 bg-vibe-surface/78 p-4 shadow-sm">
      <h2 class="mb-3 text-sm font-semibold text-vibe-fg-strong">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end
end
