defmodule Vibe.Web.Session.Components do
  @moduledoc "Components specific to the session workbench."
  use Phoenix.Component

  alias Vibe.Web.Session.{Messages, Status}

  import Vibe.Web.Components.Tool, only: [tool_card: 1]

  defp effort_label(effort) when effort in [:off, :minimal, :low, :medium, :high, :xhigh],
    do: Atom.to_string(effort)

  defp effort_label(nil), do: "off"
  defp effort_label(effort), do: to_string(effort)

  attr(:label, :string, required: true)

  def activity_row(assigns) do
    ~H"""
    <article class="flex items-center gap-2 rounded-lg border border-orange-300/15 bg-orange-300/[0.045] px-3 py-2 text-sm text-orange-100/90">
      <span class="size-2 rounded-full bg-orange-300 animate-pulse"></span>
      <span>{@label}</span>
    </article>
    """
  end

  attr(:state, :map, required: true)

  def status_strip(assigns) do
    ~H"""
    <section class="mb-3 rounded-xl border border-white/10 bg-[#141219]/80 px-3 py-3 sm:px-4">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div class="min-w-0">
          <div class="flex items-center gap-2 text-sm font-medium text-zinc-100">
            <span class={[
              "size-2 rounded-full",
              if(Status.working?(@state), do: "animate-pulse bg-orange-300", else: "bg-emerald-300/80")
            ]}></span>
            <span>{if Status.working?(@state), do: "Working…", else: "Idle"}</span>
          </div>
          <p :if={Status.activity_label(@state)} class="mt-1 truncate text-xs text-zinc-500">{Status.activity_label(@state)}</p>
        </div>
        <div class="flex min-w-0 flex-wrap items-center gap-2 text-xs text-zinc-500">
          <span :for={{key, text} <- Map.get(@state, :plugin_statuses, %{})} class="rounded-full border border-violet-300/15 bg-violet-300/10 px-2 py-0.5 text-violet-100">
            <span class="font-mono text-violet-200/70">{key}</span> {text}
          </span>
          <span class="truncate">{@state.model}</span>
          <span>{effort_label(@state.effort)}</span>
          <span class="truncate font-mono">{@state.cwd}</span>
        </div>
      </div>
    </section>
    """
  end

  attr(:state, :map, required: true)

  def session_sidebar(assigns) do
    ~H"""
    <Vibe.Web.Components.Core.panel title="Session">
      <div class="space-y-3 text-sm text-zinc-300">
        <div>
          <p class="text-[0.68rem] uppercase tracking-[0.2em] text-zinc-500">Workspace</p>
          <p class="mt-1 break-words font-mono text-xs [overflow-wrap:anywhere]">{@state.cwd}</p>
        </div>
        <div class="flex min-w-0 justify-between gap-4"><span class="text-zinc-500">Model</span><span class="truncate">{@state.model}</span></div>
        <div class="flex justify-between gap-4"><span class="text-zinc-500">Effort</span><span>{effort_label(@state.effort)}</span></div>
        <div class="flex justify-between gap-4"><span class="text-zinc-500">Status</span><Vibe.Web.Components.Core.status_badge status={@state.status} /></div>
        <div class="flex justify-between gap-4"><span class="text-zinc-500">Messages</span><span class="tabular-nums">{length(@state.messages)}</span></div>
        <div :if={map_size(Map.get(@state, :plugin_statuses, %{})) > 0}>
          <p class="text-[0.68rem] uppercase tracking-[0.2em] text-zinc-500">Plugin status</p>
          <div class="mt-2 space-y-1">
            <div :for={{key, text} <- Map.get(@state, :plugin_statuses, %{})} class="rounded-md bg-violet-300/10 px-2 py-1 text-xs text-violet-100">
              <span class="font-mono text-violet-200/70">{key}</span> {text}
            </div>
          </div>
        </div>
      </div>
    </Vibe.Web.Components.Core.panel>
    """
  end

  attr(:state, :map, required: true)

  def mobile_meta(assigns) do
    ~H"""
    <div class="rounded-xl border border-white/10 bg-[#17151d]/78 p-3 text-xs text-zinc-400">
      <div class="flex items-center justify-between gap-3">
        <Vibe.Web.Components.Core.status_badge status={@state.status} />
        <span class="tabular-nums">{length(@state.messages)} messages</span>
      </div>
      <p class="mt-2 truncate">{@state.model} · {effort_label(@state.effort)}</p>
      <p class="mt-1 truncate font-mono">{@state.cwd}</p>
    </div>
    """
  end

  attr(:cursor, :integer, required: true)
  attr(:state, :map, required: true)

  def runtime_inspector(assigns) do
    ~H"""
    <Vibe.Web.Components.Core.panel title="Runtime">
      <div class="space-y-3 text-sm text-zinc-300">
        <div class="flex justify-between"><span class="text-zinc-500">Cursor</span><span class="tabular-nums">{@cursor}</span></div>
        <div class="flex justify-between"><span class="text-zinc-500">Pending tools</span><span class="tabular-nums">{map_size(@state.pending_tools || %{})}</span></div>
        <div class="flex justify-between"><span class="text-zinc-500">Notifications</span><span class="tabular-nums">{length(@state.notifications || [])}</span></div>
      </div>
    </Vibe.Web.Components.Core.panel>
    """
  end

  attr(:state, :map, required: true)

  def tool_timeline(assigns) do
    assigns = assign(assigns, :tools, tool_messages(assigns.state))

    ~H"""
    <Vibe.Web.Components.Core.panel title="Tools">
      <div :if={@tools == []} class="text-sm leading-6 text-zinc-500">
        No tools have run in this session.
      </div>

      <div :if={@tools != []} class="space-y-2">
        <details :for={{tool, index} <- Enum.with_index(@tools)} class="group overflow-hidden rounded-lg border border-white/10 bg-[#0d0c11]/55">
          <summary class="flex cursor-pointer list-none items-start justify-between gap-2 px-3 py-2 marker:hidden">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-zinc-100">{tool_summary(tool).name}</p>
              <p :if={tool_summary(tool).summary not in [nil, ""]} class="mt-0.5 truncate font-mono text-xs text-zinc-600">{tool_summary(tool).summary}</p>
            </div>
            <span class="shrink-0 rounded bg-white/[0.04] px-1.5 py-0.5 font-mono text-[0.65rem] text-zinc-600">#{index + 1}</span>
          </summary>
          <div class="border-t border-white/8 p-2">
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
          <div class="rounded-xl border border-dashed border-white/15 p-8 text-center text-sm text-zinc-500">No messages yet. Start with the composer below.</div>
        <% end %>

        <%= for message <- Messages.display(@state.messages, @final_assistant_messages, Status.visible_stream?(@state)) do %>
          <Vibe.Web.Components.Message.message_card message={message} />
        <% end %>

        <.activity_row :if={Status.working?(@state) and !Status.visible_stream?(@state)} label={Status.activity_label(@state) || "Thinking…"} />
      </div>
    </div>
    """
  end

  attr(:state, :map, required: true)
  attr(:prompt, :string, required: true)

  def composer(assigns) do
    ~H"""
    <form id="session-composer" phx-submit="submit" phx-hook="SubmitShortcut" class="border-t border-white/10 bg-[#17151d]/90 p-3 sm:p-4">
      <label class="sr-only" for="session-prompt">Message Vibe</label>
      <textarea id="session-prompt" name="prompt" value={@prompt} rows="2" autocomplete="off" placeholder="Ask Vibe. Use /help, /model, /sessions, or plain language…" class="min-h-16 w-full resize-y rounded-lg border border-white/10 bg-[#0d0c11]/85 px-3 py-2 text-sm leading-6 text-zinc-100 ring-orange-300/20 placeholder:text-zinc-600 focus:border-orange-300 focus:outline-none focus:ring-4 sm:min-h-20"></textarea>
      <div class="mt-3 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p class="text-xs leading-5 text-zinc-500">{if Status.working?(@state), do: Status.activity_label(@state) || "Working…", else: "Ready · Cmd+Enter to send"}</p>
        <div class="flex justify-end gap-2">
          <button :if={Status.working?(@state)} type="button" phx-click="cancel" class="rounded-lg border border-red-300/30 bg-red-400/10 px-4 py-2 text-sm font-medium text-red-100 transition-colors hover:border-red-300/60 hover:bg-red-400/15 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-red-300/60">Stop</button>
          <button :if={!Status.working?(@state)} class="rounded-lg bg-orange-400 px-5 py-2 text-sm font-semibold text-zinc-950 shadow-lg shadow-orange-950/20 transition-colors hover:bg-orange-300 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">Send</button>
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
    display = Vibe.Tool.Display.from_tool(tool)

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
