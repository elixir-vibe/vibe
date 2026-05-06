defmodule Vibe.Web.SettingsLive do
  @moduledoc "LiveView for Vibe model, auth, and local configuration status."
  use Vibe.Web, :live_view

  alias Vibe.Agent.Profile
  alias Vibe.Auth
  alias Vibe.Auth.Store
  alias Vibe.Prompts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_settings(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:settings} title="Settings" subtitle="Local profiles, model defaults, and authentication state.">
      <div class="grid gap-4 lg:grid-cols-2">
        <.panel title="Models">
          <dl class="space-y-3 text-sm text-vibe-fg">
            <div class="flex justify-between gap-4">
              <dt class="text-vibe-dim">Default model</dt>
              <dd class="min-w-0 truncate font-mono text-vibe-fg-strong">{@default_model}</dd>
            </div>
            <div class="flex justify-between gap-4">
              <dt class="text-vibe-dim">Default effort</dt>
              <dd class="font-mono text-vibe-fg-strong">{Atom.to_string(@default_effort)}</dd>
            </div>
            <div class="flex justify-between gap-4">
              <dt class="text-vibe-dim">Profile file</dt>
              <dd class="min-w-0 truncate font-mono text-xs text-vibe-muted">{@profile_path}</dd>
            </div>
          </dl>
        </.panel>

        <.panel title="Auth">
          <div class="space-y-2">
            <div :for={provider <- @auth_providers} class="flex items-center justify-between gap-3 rounded-lg border border-vibe-border/40 bg-vibe-bg/55 px-3 py-2 text-sm">
              <div class="min-w-0">
                <p class="truncate font-medium text-vibe-fg-strong">{provider.name}</p>
                <p class="truncate font-mono text-xs text-vibe-dim">{provider.module}</p>
              </div>
              <.status_badge status={provider.status} />
            </div>
          </div>
        </.panel>
      </div>

      <section class="mt-4 overflow-hidden rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80">
        <header class="border-b border-vibe-border/50 px-4 py-3">
          <h2 class="text-base font-semibold text-vibe-fg-strong">Prompts</h2>
          <p class="mt-1 text-sm text-vibe-dim">Built-in prompt templates compiled into Vibe.</p>
        </header>
        <div class="divide-y divide-white/8">
          <details :for={prompt <- @prompts} class="group">
            <summary class="flex cursor-pointer list-none items-center justify-between gap-4 px-4 py-3 marker:hidden hover:bg-vibe-surface-muted/35">
              <div class="min-w-0">
                <h3 class="truncate text-sm font-semibold text-vibe-fg-strong">{prompt.title}</h3>
                <p class="mt-1 text-xs text-vibe-dim">{prompt.lines} lines · {prompt.bytes} bytes</p>
              </div>
              <span class="text-xs text-vibe-dim transition-transform group-open:rotate-90">›</span>
            </summary>
            <div class="border-t border-vibe-border/40 bg-vibe-bg/55 p-4">
              <pre class="max-h-96 overflow-auto whitespace-pre-wrap break-words rounded-lg bg-vibe-code p-3 font-mono text-xs leading-5 text-vibe-fg [overflow-wrap:anywhere]">{prompt.text}</pre>
            </div>
          </details>
        </div>
      </section>

      <section class="mt-4 rounded-xl border border-vibe-border/50 bg-vibe-bg-soft/80 p-4">
        <header class="mb-4 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 class="text-base font-semibold text-vibe-fg-strong">Roles</h2>
            <p class="mt-1 text-sm text-vibe-dim">Configured agent roles from the editable TOML profile.</p>
          </div>
          <span class="font-mono text-xs text-vibe-dim">{length(@roles)} roles</span>
        </header>

        <div :if={@roles == []} class="rounded-lg border border-dashed border-vibe-border/60 p-8 text-center text-sm text-vibe-dim">No roles configured.</div>
        <div :if={@roles != []} class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <article :for={role <- @roles} class="flex min-h-44 flex-col rounded-lg border border-vibe-border/50 bg-vibe-bg/55 p-4 transition-colors hover:border-vibe-border">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-vibe-accent/75">Role</p>
                <h3 class="mt-1 truncate text-lg font-semibold text-vibe-fg-strong">{role.name}</h3>
              </div>
              <span class="shrink-0 rounded-full border border-vibe-border/50 bg-vibe-surface-muted/35 px-2 py-1 font-mono text-[0.68rem] text-vibe-muted">{length(role.tools)} tools</span>
            </div>

            <p :if={role.system} class="mt-3 line-clamp-3 text-sm leading-6 text-vibe-fg">{role.system}</p>

            <div class="mt-auto pt-4">
              <p class="text-[0.62rem] font-semibold uppercase tracking-[0.16em] text-vibe-dim">Model</p>
              <p :if={role.model} class="mt-1 truncate rounded-md bg-vibe-surface-muted/35 px-2 py-1 font-mono text-xs text-vibe-muted">{role.model}</p>
              <p :if={!role.model} class="mt-1 text-xs text-vibe-dim">Uses default model</p>
              <p class="mt-2 text-[0.62rem] font-semibold uppercase tracking-[0.16em] text-vibe-dim">Effort</p>
              <p class="mt-1 font-mono text-xs text-vibe-dim">{Atom.to_string(role.effort || @default_effort)}</p>
            </div>
          </article>
        </div>
      </section>
    </.app_shell>
    """
  end

  defp assign_settings(socket) do
    profile_data = load_profile()

    socket
    |> assign(:default_model, Profile.default_model())
    |> assign(:default_effort, Profile.default_effort())
    |> assign(:profile_path, Profile.path())
    |> assign(:roles, roles(profile_data))
    |> assign(:auth_providers, auth_providers())
    |> assign(:prompts, prompts())
  end

  defp load_profile do
    case Profile.load() do
      {:ok, data} -> data
      {:error, _reason} -> %{}
    end
  end

  defp roles(profile_data) do
    profile_data
    |> Map.get("roles", %{})
    |> Enum.map(fn {name, data} ->
      %{
        name: name,
        model: Map.get(data, "model"),
        effort: role_effort(data),
        system: Map.get(data, "system"),
        tools: Map.get(data, "tools", [])
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp role_effort(data) do
    with value when is_binary(value) <- Map.get(data, "effort"),
         {:ok, effort} <- Vibe.Model.Effort.from_string(value) do
      effort
    else
      _ -> nil
    end
  end

  defp prompts do
    [
      {:system, "System prompt", Prompts.system()},
      {:summarization_system, "Summarization system", Prompts.summarization_system()},
      {:context_summary, "Context summary", Prompts.context_summary()},
      {:context_update, "Context update", Prompts.context_update()},
      {:turn_prefix_summary, "Turn prefix summary", Prompts.turn_prefix_summary()}
    ]
    |> Enum.map(fn {name, title, text} ->
      %{
        name: name,
        title: title,
        text: text,
        lines: text |> String.split("\n") |> length(),
        bytes: byte_size(text)
      }
    end)
  end

  defp auth_providers do
    Auth.providers()
    |> Enum.uniq_by(fn {name, _module} -> canonical_provider(name) end)
    |> Enum.map(fn {name, module} ->
      %{
        name: name,
        module: inspect(module),
        status: auth_status(name)
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp auth_status(provider) do
    case Store.load(canonical_provider(provider)) do
      {:ok, _credentials} -> :ok
      {:error, :not_found} -> :idle
      {:error, _reason} -> :error
    end
  end

  defp canonical_provider(provider) when provider in ["codex", "openai-codex"], do: "openai-codex"

  defp canonical_provider(provider) when provider in ["openrouter", "open-router"],
    do: "openrouter"

  defp canonical_provider(provider), do: provider
end
