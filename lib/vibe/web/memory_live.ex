defmodule Vibe.Web.MemoryLive do
  @moduledoc "LiveView page for durable Vibe memory."
  use Vibe.Web, :live_view

  alias Vibe.Memory

  @scope_options [
    {"User memory", :user},
    {"Global memory", :global}
  ]

  @scope_by_param Map.new(@scope_options, fn {_label, scope} -> {Atom.to_string(scope), scope} end)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:scope_options, @scope_options)
     |> assign(:new_memory_text, "")
     |> assign(:new_memory_scope, :user)
     |> assign_memory("")}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, assign_memory(socket, query)}
  end

  def handle_event("add", %{"memory" => %{"scope" => scope_param, "text" => text}}, socket) do
    scope = scope_from_param(scope_param)

    case Memory.add(scope, text) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Memory saved.")
         |> assign(:new_memory_text, "")
         |> assign(:new_memory_scope, scope)
         |> assign_memory(socket.assigns.query)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("delete", %{"scope" => scope_param, "id" => id}, socket) do
    case Memory.remove(scope_from_param(scope_param), id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Memory deleted.")
         |> assign_memory(socket.assigns.query)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete memory: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:memory} title="Memory" subtitle="Curated durable facts Vibe can recall across sessions and workspaces.">
      <section class="mb-4 rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80 p-3 sm:p-4">
        <form phx-submit="add" class="space-y-3">
          <label class="sr-only" for="memory-text">Add memory</label>
          <textarea id="memory-text" name="memory[text]" value={@new_memory_text} rows="3" placeholder="Add a durable memory Vibe should remember…" class="min-h-24 w-full resize-y rounded-lg border border-vibe-border/50 bg-vibe-bg px-3 py-2 text-sm leading-6 text-vibe-fg-strong placeholder:text-vibe-dim focus:border-vibe-accent focus:outline-none focus:ring-2 focus:ring-vibe-accent/25"></textarea>
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <select name="memory[scope]" class="rounded-lg border border-vibe-border/50 bg-vibe-bg px-3 py-2 text-sm text-vibe-fg-strong focus:border-vibe-accent focus:outline-none focus:ring-2 focus:ring-vibe-accent/25">
              <option :for={{label, scope} <- @scope_options} value={scope_param(scope)} selected={@new_memory_scope == scope}>{label}</option>
            </select>
            <button class="rounded-lg bg-vibe-accent px-4 py-2 text-sm font-semibold text-vibe-accent-contrast shadow-lg shadow-vibe-accent/20 transition-colors hover:bg-vibe-accent-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70">Save memory</button>
          </div>
        </form>
      </section>

      <section class="rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80">
        <form phx-change="search" class="border-b border-vibe-border/50 p-3 sm:p-4">
          <label class="sr-only" for="memory-search">Search memory</label>
          <input id="memory-search" name="q" value={@query} autocomplete="off" placeholder="Search memory…" class="w-full rounded-lg border border-vibe-border/50 bg-vibe-bg px-3 py-2 text-sm text-vibe-fg-strong placeholder:text-vibe-dim focus:border-vibe-accent focus:outline-none focus:ring-2 focus:ring-vibe-accent/25" />
        </form>

        <div :if={@entries == []} class="p-10 text-center text-sm text-vibe-dim">No memory entries matched.</div>
        <div :if={@entries != []} class="divide-y divide-white/8">
          <article :for={entry <- @entries} class="px-4 py-3">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <div class="flex min-w-0 flex-wrap items-center gap-2 text-xs text-vibe-dim">
                <span class="rounded bg-vibe-surface-muted/35 px-1.5 py-0.5">{scope_label(entry.scope)}</span>
                <span class="font-mono">{entry.id}</span>
                <span :if={entry.at}>{Calendar.strftime(entry.at, "%Y-%m-%d %H:%M")}</span>
              </div>
              <button type="button" phx-click="delete" phx-value-scope={scope_value(entry.scope)} phx-value-id={entry.id} class="rounded border border-vibe-error/15 px-2 py-1 text-xs text-vibe-error/80 hover:border-vibe-error/40 hover:text-vibe-error">Delete</button>
            </div>
            <p class="mt-2 whitespace-pre-wrap text-sm leading-6 text-vibe-fg-strong">{entry.text}</p>
          </article>
        </div>
      </section>
    </.app_shell>
    """
  end

  defp assign_memory(socket, query) do
    entries =
      if String.trim(query || "") == "" do
        Memory.list(:global) ++ Memory.list(:user)
      else
        Memory.search(query, scopes: [:global, :user], limit: 50)
      end

    socket
    |> assign(:query, query)
    |> assign(:entries, entries)
  end

  defp scope_from_param(param), do: Map.get(@scope_by_param, param, :user)

  defp scope_value(scope), do: scope |> scope_from_storage() |> scope_param()

  defp scope_param(scope) when is_atom(scope), do: Atom.to_string(scope)

  defp scope_from_storage(:global), do: :global
  defp scope_from_storage(:user), do: :user
  defp scope_from_storage(_scope), do: :user

  defp scope_label({scope, value}), do: "#{scope}:#{value}"
  defp scope_label(scope), do: to_string(scope)
end
