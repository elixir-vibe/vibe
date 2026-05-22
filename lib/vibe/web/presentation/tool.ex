defmodule Vibe.Web.Presentation.Tool do
  @moduledoc "Web surface projection for tool presentations."
  use Phoenix.Component

  alias Vibe.Presentation.Presentable
  alias Vibe.Web.Components.Code

  attr(:tool, :map, required: true)

  def tool_card(assigns) do
    assigns = assign(assigns, :display, Presentable.present(assigns.tool))

    ~H"""
    <article class="overflow-hidden rounded-lg border border-vibe-accent/15 bg-vibe-surface/70">
      <header class="flex min-w-0 flex-col gap-2 px-3 py-2 sm:flex-row sm:items-start sm:justify-between sm:px-4">
        <div class="min-w-0">
          <div class="flex min-w-0 flex-wrap items-center gap-2">
            <h3 class="text-sm font-semibold text-vibe-fg-strong">{tool_name(@display.name)}</h3>
            <Vibe.Web.Components.Core.status_badge :if={(@display.status || @tool.status) not in [:ok, "ok"]} status={@display.status || @tool.status || :running} />
          </div>
          <div :if={Code.display_text(@display.summary) not in [nil, ""]} class="mt-1 break-words font-mono text-xs leading-5 text-vibe-dim [overflow-wrap:anywhere]">
            <%= if @display.summary_style == :elixir_dim do %>
              {Phoenix.HTML.raw(Code.summary_html(Code.display_text(@display.summary)))}
            <% else %>
              {Code.display_text(@display.summary)}
            <% end %>
          </div>
        </div>
        <div :if={@display.meta != []} class="flex shrink-0 flex-wrap gap-1 text-xs text-vibe-dim">
          <span :for={meta <- @display.meta} class="rounded bg-vibe-surface-muted/35 px-1.5 py-0.5">{Code.display_text(meta)}</span>
        </div>
      </header>

      <div class="space-y-2 px-3 pb-3 sm:px-4">
        <%= if @display.body == [] do %>
          <p class="text-sm text-vibe-dim">No tool output.</p>
        <% else %>
          <%= for block <- @display.body do %>
            <.tool_body_block block={block} truncate?={false} />
          <% end %>
        <% end %>
      </div>
    </article>
    """
  end

  attr(:block, :any, required: true)
  attr(:truncate?, :boolean, default: true)

  def tool_body_block(assigns) do
    assigns =
      assign(
        assigns,
        :body,
        Vibe.Web.Presentation.Tool.BodyProjection.block(assigns.block, assigns.truncate?)
      )

    ~H"""
    <section class="overflow-hidden rounded-md bg-vibe-bg/72 ring-1 ring-white/8">
      <div :if={@body.label not in [nil, "", "Output", "Inspect"]} class="border-b border-vibe-border/40 px-3 py-1.5 text-[0.62rem] font-semibold uppercase tracking-[0.18em] text-vibe-dim">{@body.label}</div>

      <div :if={@body.kind in [:markdown, :source_html, :diff_html]} class={[
        "max-h-[28rem] overflow-auto px-3 py-2 text-sm leading-6 [overflow-wrap:anywhere] [&_a]:text-vibe-accent-strong [&_a]:underline [&_blockquote]:border-l-2 [&_blockquote]:border-vibe-accent/30 [&_blockquote]:pl-3 [&_blockquote]:text-vibe-fg [&_h1]:text-xl [&_h2]:text-lg [&_h3]:text-base [&_li]:ml-5 [&_ol]:list-decimal [&_p+p]:mt-3 [&_pre]:overflow-auto [&_pre]:rounded-md [&_pre]:bg-transparent [&_table]:w-full [&_table]:border-collapse [&_td]:border [&_td]:border-vibe-border/50 [&_td]:px-2 [&_td]:py-1 [&_th]:border [&_th]:border-vibe-border/50 [&_th]:px-2 [&_th]:py-1 [&_ul]:list-disc",
        if(@body.kind == :source_html,
          do: "bg-[#282c34] font-mono text-[#abb2bf] [&_code]:bg-transparent [&_code]:p-0",
          else: "text-vibe-fg [&_code]:rounded [&_code]:bg-vibe-surface-strong [&_code]:px-1"
        )
      ]}>
        {Phoenix.HTML.raw(@body.html)}
      </div>

      <figure :if={@body.kind == :image} class="space-y-2 px-3 py-2">
        <details :if={@body.collapsible?} class="group" open>
          <summary class="cursor-pointer select-none pb-2 text-xs text-vibe-dim marker:text-vibe-dim">Image preview</summary>
          <img class="max-h-[32rem] max-w-full rounded border border-vibe-border/50 object-contain" src={@body.src} alt={@body.alt} loading="lazy" />
        </details>
        <img :if={!@body.collapsible?} class="max-h-[32rem] max-w-full rounded border border-vibe-border/50 object-contain" src={@body.src} alt={@body.alt} loading="lazy" />
        <figcaption class="flex flex-wrap items-center gap-x-2 gap-y-1 font-mono text-[0.68rem] leading-4 text-vibe-dim">
          <span>{@body.caption}</span>
          <a :if={@body.original_url} class="text-vibe-accent-strong underline decoration-vibe-accent-strong/40 hover:text-vibe-accent-strong" href={@body.original_url} target="_blank" rel="noopener">Open original</a>
        </figcaption>
      </figure>

      <pre :if={@body.kind not in [:markdown, :source_html, :diff_html, :image]} class={[
        "max-h-[28rem] overflow-auto whitespace-pre-wrap break-words px-3 py-2 text-xs leading-5 [overflow-wrap:anywhere]",
        if(@body.kind == :error, do: "text-vibe-error", else: "text-vibe-fg"),
        if(@body.mono?, do: "font-mono", else: "font-sans")
      ]}>{@body.text}</pre>
    </section>
    """
  end

  defp tool_name(name) when is_atom(name), do: name |> Atom.to_string() |> String.capitalize()
  defp tool_name(name) when is_binary(name), do: String.capitalize(name)
  defp tool_name(_name), do: "Tool"
end
