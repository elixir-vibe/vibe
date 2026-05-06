defmodule Vibe.Web.SkillsLive do
  @moduledoc "LiveView for installed Markdown and executable Vibe skills."
  use Vibe.Web, :live_view

  alias Vibe.Skill

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    {:ok, assign_skill(socket, name)}
  end

  def mount(_params, _session, socket) do
    {:ok, assign_skills(socket)}
  end

  @impl true
  def render(%{skill: skill} = assigns) when is_map(skill) do
    ~H"""
    <.app_shell current={:skills} title={@skill.name} subtitle={@skill.title || "Installed Vibe skill"}>
      <.link navigate={~p"/skills"} class="mb-3 inline-flex text-sm text-zinc-500 hover:text-zinc-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">← Skills</.link>

      <section class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_20rem]">
        <article class="rounded-xl border border-white/10 bg-[#141219]/80 p-4 sm:p-5">
          <div class="mb-4 flex flex-wrap gap-2 text-xs">
            <span class="rounded bg-orange-300/10 px-2 py-1 font-semibold uppercase tracking-[0.16em] text-orange-200">{skill_type(@skill.type)}</span>
            <span :if={@skill.apis != []} class="rounded bg-violet-300/10 px-2 py-1 font-mono text-violet-100">{length(@skill.apis)} APIs</span>
          </div>
          <PhoenixStreamdown.markdown id={"skill-#{@skill.name}"} content={@skill.markdown || ""} streaming={false} class="vibe-markdown" mdex_opts={[render: [unsafe: false]]} />
        </article>

        <aside class="space-y-4">
          <.panel title="Details">
            <dl class="space-y-3 text-sm text-zinc-300">
              <div>
                <dt class="text-zinc-500">Path</dt>
                <dd class="mt-1 break-words font-mono text-xs text-zinc-400 [overflow-wrap:anywhere]">{@skill.path}</dd>
              </div>
              <div :if={Map.get(@skill, :module)}>
                <dt class="text-zinc-500">Module</dt>
                <dd class="mt-1 break-words font-mono text-xs text-zinc-400 [overflow-wrap:anywhere]">{inspect(@skill.module)}</dd>
              </div>
            </dl>
          </.panel>

          <.panel :if={@skill.apis != []} title="Eval APIs">
            <.api_sections apis={@skill.apis} />
          </.panel>
        </aside>
      </section>
    </.app_shell>
    """
  end

  def render(assigns) do
    ~H"""
    <.app_shell current={:skills} title="Skills" subtitle="Reusable workflow knowledge available to Vibe agents.">
      <section class="overflow-hidden rounded-xl border border-white/10 bg-[#141219]/80">
        <div class="grid gap-px border-b border-white/10 bg-white/10 sm:grid-cols-4">
          <.skill_metric label="Total" value={length(@skills)} />
          <.skill_metric label="Markdown" value={@markdown_count} />
          <.skill_metric label="Executable" value={@executable_count} />
          <.skill_metric label="APIs" value={@api_count} />
        </div>

        <div class="border-b border-white/10 px-4 py-3">
          <h2 class="text-sm font-semibold text-zinc-100">Skill paths</h2>
          <div class="mt-2 flex flex-wrap gap-2">
            <span :for={path <- @script_paths} class="rounded bg-white/[0.035] px-2 py-1 font-mono text-xs text-zinc-500">{path}</span>
          </div>
        </div>

        <div :if={@skills == []} class="p-10 text-center text-sm text-zinc-500">No skills installed.</div>
        <div :if={@skills != []} class="grid gap-3 p-4 md:grid-cols-2 xl:grid-cols-3">
          <.link :for={skill <- @skills} navigate={~p"/skills/#{skill.name}"} class="flex min-h-44 flex-col rounded-lg border border-white/10 bg-[#0d0c11]/55 p-4 transition-colors hover:border-white/20 hover:bg-white/[0.025] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.18em] text-orange-300/75">{skill_type(skill.type)}</p>
                <h3 class="mt-1 truncate text-lg font-semibold text-zinc-50">{skill.name}</h3>
              </div>
              <span :if={skill.apis != []} class="shrink-0 rounded-full border border-violet-300/20 bg-violet-300/10 px-2 py-1 font-mono text-[0.68rem] text-violet-100">{length(skill.apis)} APIs</span>
            </div>

            <p :if={skill.title} class="mt-3 line-clamp-3 text-sm leading-6 text-zinc-300">{skill.title}</p>
            <p class="mt-auto break-words pt-4 font-mono text-xs leading-5 text-zinc-600 [overflow-wrap:anywhere]">{skill.path}</p>
          </.link>
        </div>
      </section>
    </.app_shell>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :any, required: true)

  def skill_metric(assigns) do
    ~H"""
    <div class="bg-[#141219] px-4 py-3">
      <p class="text-[0.65rem] font-medium uppercase tracking-[0.18em] text-zinc-600">{@label}</p>
      <p class="mt-1 font-mono text-xl text-zinc-100 tabular-nums">{@value}</p>
    </div>
    """
  end

  defp assign_skills(socket) do
    skills = Skill.list()

    socket
    |> assign(:skills, skills)
    |> assign(:script_paths, Skill.script_paths())
    |> assign(:markdown_count, Enum.count(skills, &(&1.type == :markdown)))
    |> assign(:executable_count, Enum.count(skills, &(&1.type == :exs)))
    |> assign(:api_count, skills |> Enum.flat_map(& &1.apis) |> length())
  end

  defp assign_skill(socket, name) do
    case Skill.get(name) do
      {:ok, skill} ->
        assign(socket, :skill, skill)

      {:error, reason} ->
        assign(socket,
          skill: %{
            name: "Skill not found",
            title: reason,
            type: :missing,
            path: nil,
            markdown: reason,
            apis: []
          }
        )
    end
  end

  defp skill_type(:exs), do: "Executable"
  defp skill_type(:missing), do: "Missing"
  defp skill_type(_type), do: "Markdown"
end
