defmodule Exy.Web.SettingsLive do
  @moduledoc "LiveView for Exy model, auth, and local configuration status."
  use Exy.Web, :live_view

  alias Exy.Agent.Profile
  alias Exy.Auth
  alias Exy.Auth.Store
  alias Exy.Prompts

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
          <dl class="space-y-3 text-sm text-zinc-300">
            <div class="flex justify-between gap-4">
              <dt class="text-zinc-500">Default model</dt>
              <dd class="min-w-0 truncate font-mono text-zinc-100">{@default_model}</dd>
            </div>
            <div class="flex justify-between gap-4">
              <dt class="text-zinc-500">Default effort</dt>
              <dd class="font-mono text-zinc-100">{Atom.to_string(@default_effort)}</dd>
            </div>
            <div class="flex justify-between gap-4">
              <dt class="text-zinc-500">Profile file</dt>
              <dd class="min-w-0 truncate font-mono text-xs text-zinc-400">{@profile_path}</dd>
            </div>
          </dl>
        </.panel>

        <.panel title="Auth">
          <div class="space-y-2">
            <div :for={provider <- @auth_providers} class="flex items-center justify-between gap-3 rounded-lg border border-white/8 bg-[#0d0c11]/55 px-3 py-2 text-sm">
              <div class="min-w-0">
                <p class="truncate font-medium text-zinc-100">{provider.name}</p>
                <p class="truncate font-mono text-xs text-zinc-600">{provider.module}</p>
              </div>
              <.status_badge status={provider.status} />
            </div>
          </div>
        </.panel>
      </div>

      <section class="mt-4 overflow-hidden rounded-xl border border-white/10 bg-[#141219]/80">
        <header class="border-b border-white/10 px-4 py-3">
          <h2 class="text-base font-semibold text-zinc-100">Prompts</h2>
          <p class="mt-1 text-sm text-zinc-500">Built-in prompt templates compiled into Exy.</p>
        </header>
        <div class="divide-y divide-white/8">
          <details :for={prompt <- @prompts} class="group">
            <summary class="flex cursor-pointer list-none items-center justify-between gap-4 px-4 py-3 marker:hidden hover:bg-white/[0.025]">
              <div class="min-w-0">
                <h3 class="truncate text-sm font-semibold text-zinc-100">{prompt.title}</h3>
                <p class="mt-1 text-xs text-zinc-600">{prompt.lines} lines · {prompt.bytes} bytes</p>
              </div>
              <span class="text-xs text-zinc-600 transition-transform group-open:rotate-90">›</span>
            </summary>
            <div class="border-t border-white/8 bg-[#0d0c11]/55 p-4">
              <pre class="max-h-96 overflow-auto whitespace-pre-wrap break-words rounded-lg bg-[#09080c] p-3 font-mono text-xs leading-5 text-zinc-300 [overflow-wrap:anywhere]">{prompt.text}</pre>
            </div>
          </details>
        </div>
      </section>

      <section class="mt-4 rounded-xl border border-white/10 bg-[#141219]/80 p-4">
        <header class="mb-4 flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h2 class="text-base font-semibold text-zinc-100">Roles</h2>
            <p class="mt-1 text-sm text-zinc-500">Configured agent roles from the editable TOML profile.</p>
          </div>
          <span class="font-mono text-xs text-zinc-600">{length(@roles)} roles</span>
        </header>

        <div :if={@roles == []} class="rounded-lg border border-dashed border-white/15 p-8 text-center text-sm text-zinc-500">No roles configured.</div>
        <div :if={@roles != []} class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <article :for={role <- @roles} class="flex min-h-44 flex-col rounded-lg border border-white/10 bg-[#0d0c11]/55 p-4 transition-colors hover:border-white/20">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-orange-300/75">Role</p>
                <h3 class="mt-1 truncate text-lg font-semibold text-zinc-50">{role.name}</h3>
              </div>
              <span class="shrink-0 rounded-full border border-white/10 bg-white/[0.035] px-2 py-1 font-mono text-[0.68rem] text-zinc-400">{length(role.tools)} tools</span>
            </div>

            <p :if={role.system} class="mt-3 line-clamp-3 text-sm leading-6 text-zinc-300">{role.system}</p>

            <div class="mt-auto pt-4">
              <p class="text-[0.62rem] font-semibold uppercase tracking-[0.16em] text-zinc-600">Model</p>
              <p :if={role.model} class="mt-1 truncate rounded-md bg-white/[0.035] px-2 py-1 font-mono text-xs text-zinc-400">{role.model}</p>
              <p :if={!role.model} class="mt-1 text-xs text-zinc-600">Uses default model</p>
              <p class="mt-2 text-[0.62rem] font-semibold uppercase tracking-[0.16em] text-zinc-600">Effort</p>
              <p class="mt-1 font-mono text-xs text-zinc-500">{Atom.to_string(role.effort || @default_effort)}</p>
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
         {:ok, effort} <- Exy.Model.Effort.from_string(value) do
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
