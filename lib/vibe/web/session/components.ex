defmodule Vibe.Web.Session.Components do
  @moduledoc "Components specific to the session workbench."
  use Phoenix.Component

  alias Vibe.Web.Session.{Activity, Messages}

  import PhoenixIconify, only: [icon: 1]
  import Vibe.Web.Presentation.Tool, only: [tool_card: 1]

  alias Vibe.Presentation.Presentable

  defp effort_label(effort) when effort in [:off, :minimal, :low, :medium, :high, :xhigh],
    do: Atom.to_string(effort)

  defp effort_label(nil), do: "off"
  defp effort_label(effort), do: to_string(effort)

  attr(:label, :string, required: true)

  def activity_row(assigns) do
    ~H"""
    <article class="flex items-center gap-2 rounded-lg border border-vibe-accent/15 bg-vibe-accent/[0.045] px-3 py-2 text-sm text-vibe-accent-strong/90">
      <.icon name="lucide:loader-circle" class="size-4 animate-spin" />
      <span>{@label}</span>
    </article>
    """
  end

  attr(:state, :map, required: true)

  def status_strip(assigns) do
    ~H"""
    <section class="mb-3 rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80 px-3 py-3 sm:px-4">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="min-w-0">
          <div class="flex items-center gap-2 text-sm font-medium text-vibe-fg-strong">
            <.icon :if={Activity.working?(@state)} name="lucide:loader-circle" class="size-4 animate-spin text-vibe-accent" />
            <.icon :if={!Activity.working?(@state)} name="lucide:circle-check" class="size-4 text-vibe-success" />
            <span>{if Activity.working?(@state), do: "Working…", else: "Idle"}</span>
          </div>
          <p :if={Activity.activity_label(@state)} class="mt-1 truncate text-xs text-vibe-dim">{Activity.activity_label(@state)}</p>
          <p :if={@state.goal} class="mt-1 truncate text-xs text-vibe-dim">
            Goal: <span class="text-vibe-fg">{@state.goal.objective}</span>
          </p>
        </div>
        <div class="flex min-w-0 flex-wrap items-center gap-2 text-xs text-vibe-dim">
          <span :for={{key, text} <- Map.get(@state, :plugin_statuses, %{})} class="rounded-full border border-vibe-accent/15 bg-vibe-accent/10 px-2 py-0.5 text-vibe-accent-strong">
            <span class="font-mono text-vibe-accent-strong/70">{key}</span> {text}
          </span>
          <span class="truncate">{@state.model}</span>
          <span>{effort_label(@state.effort)}</span>
          <span class="truncate font-mono">{@state.cwd}</span>
        </div>
      </div>
    </section>
    """
  end

  attr(:cursor, :integer, required: true)
  attr(:state, :map, required: true)

  def runtime_inspector(assigns) do
    ~H"""
    <Vibe.Web.Components.Core.panel title="Runtime">
      <div class="space-y-3 text-sm text-vibe-fg">
        <div class="flex justify-between"><span class="text-vibe-dim">Cursor</span><span class="tabular-nums">{@cursor}</span></div>
        <div class="flex justify-between"><span class="text-vibe-dim">Pending tools</span><span class="tabular-nums">{map_size(@state.pending_tools || %{})}</span></div>
        <div class="flex justify-between"><span class="text-vibe-dim">Notifications</span><span class="tabular-nums">{length(@state.notifications || [])}</span></div>
      </div>
    </Vibe.Web.Components.Core.panel>
    """
  end

  attr(:state, :map, required: true)

  def tool_timeline(assigns) do
    assigns = assign(assigns, :tools, tool_messages(assigns.state))

    ~H"""
    <Vibe.Web.Components.Core.panel title="Tools">
      <div :if={@tools == []} class="text-sm leading-6 text-vibe-dim">
        No tools have run in this session.
      </div>

      <div :if={@tools != []} class="space-y-2">
        <details :for={{tool, index} <- Enum.with_index(@tools)} class="group overflow-hidden rounded-lg border border-vibe-border/50 bg-vibe-bg/55">
          <summary class="flex cursor-pointer list-none items-start justify-between gap-2 px-3 py-2 marker:hidden">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-vibe-fg-strong">{tool_summary(tool).name}</p>
              <p :if={tool_summary(tool).summary not in [nil, ""]} class="mt-0.5 truncate font-mono text-xs text-vibe-dim">{tool_summary(tool).summary}</p>
            </div>
            <span class="shrink-0 rounded bg-vibe-surface-muted/40 px-1.5 py-0.5 font-mono text-[0.65rem] text-vibe-dim">#{index + 1}</span>
          </summary>
          <div class="border-t border-vibe-border/40 p-2">
            <.tool_card tool={tool} />
          </div>
        </details>
      </div>
    </Vibe.Web.Components.Core.panel>
    """
  end

  attr(:state, :map, required: true)
  attr(:final_assistant_messages, :list, required: true)

  def transcript(assigns) do
    ~H"""
    <div id="messages" phx-hook="ScrollBottom" class="min-h-[48vh] px-3 py-3 sm:px-4 sm:py-4">
      <div class="flex flex-col gap-3">
        <%= if @state.messages == [] and is_nil(@state.streaming_message) do %>
          <div class="rounded-xl border border-dashed border-vibe-border/60 p-8 text-center text-sm text-vibe-dim">No messages yet. Start with the composer below.</div>
        <% end %>

        <%= for message <- Messages.display(@state.messages, @final_assistant_messages, Activity.visible_stream?(@state)) do %>
          <Vibe.Web.Components.Message.message_card message={message} />
        <% end %>

        <.activity_row :if={Activity.working?(@state) and !Activity.visible_stream?(@state)} label={Activity.activity_label(@state) || "Thinking…"} />
      </div>
    </div>
    """
  end

  attr(:state, :map, required: true)
  attr(:prompt, :string, required: true)

  def composer(assigns) do
    ~H"""
    <form id="session-composer" phx-submit="submit" phx-hook="SubmitShortcut" class="border-t border-vibe-border/50 bg-vibe-surface/90 p-3 sm:p-4">
      <label class="sr-only" for="session-prompt">Message Vibe</label>
      <textarea id="session-prompt" name="prompt" value={@prompt} rows="2" autocomplete="off" placeholder="Ask Vibe anything. Use /help, /model, /sessions, or plain language…" class="min-h-16 w-full resize-y rounded-lg border border-vibe-border/50 bg-vibe-bg/85 px-3 py-2 text-sm leading-6 text-vibe-fg-strong ring-vibe-accent/20 placeholder:text-vibe-dim focus:border-vibe-accent focus:outline-none focus:ring-4 sm:min-h-20"></textarea>
      <div class="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p class="inline-flex items-center gap-1.5 text-xs leading-5 text-vibe-dim">
          <.icon :if={Activity.working?(@state)} name="lucide:loader-circle" class="size-3.5 animate-spin" />
          <.icon :if={!Activity.working?(@state)} name="lucide:keyboard" class="size-3.5" />
          <span>{if Activity.working?(@state), do: Activity.activity_label(@state) || "Working…", else: "Ready · Cmd+Enter to send"}</span>
        </p>
        <div class="flex justify-end gap-2">
          <button :if={Activity.working?(@state)} type="button" phx-click="cancel" class="inline-flex items-center gap-1.5 rounded-lg border border-vibe-error/30 bg-vibe-error/10 px-4 py-2 text-sm font-medium text-vibe-error transition-colors hover:border-vibe-error/60 hover:bg-vibe-error/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-error/60">
            <.icon name="lucide:circle-stop" class="size-4" />
            <span>Stop</span>
          </button>
          <button :if={!Activity.working?(@state)} class="inline-flex items-center gap-1.5 rounded-lg bg-vibe-accent px-5 py-2 text-sm font-semibold text-vibe-accent-contrast shadow-lg shadow-vibe-accent/20 transition-colors hover:bg-vibe-accent-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-vibe-accent/70">
            <.icon name="lucide:send" class="size-4" />
            <span>Send</span>
          </button>
        </div>
      </div>
    </form>
    """
  end

  defp tool_messages(state) do
    state
    |> Map.get(:messages, [])
    |> Enum.filter(&(Map.get(&1, :role) in [:tool, "tool"]))
  end

  defp tool_summary(tool) do
    display = Presentable.present(tool)

    %{
      name: tool_name(display.name),
      summary: display_text(display.summary)
    }
  end

  defp tool_name(name) when is_atom(name), do: name |> Atom.to_string() |> String.capitalize()
  defp tool_name(name) when is_binary(name), do: String.capitalize(name)

  defp display_text(nil), do: nil
  defp display_text(text) when is_binary(text), do: text
  defp display_text(text), do: inspect(text, pretty: true, limit: 20)
end
