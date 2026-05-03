defmodule Exy.Web.JobsLive do
  @moduledoc "LiveView page for supervised subagent jobs."
  use Exy.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_jobs(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:jobs} title="Jobs" subtitle="Supervised subagents, child sessions, and background work.">
      <section class="overflow-hidden rounded-xl border border-white/10 bg-[#141219]/80">
        <header class="border-b border-white/10 px-4 py-3">
          <p class="text-sm text-zinc-400">{@job_count} jobs recorded</p>
        </header>
        <div :if={@jobs == []} class="p-10 text-center text-sm text-zinc-500">No jobs yet.</div>
        <div :if={@jobs != []} class="divide-y divide-white/8">
          <div :for={job <- @jobs} class="grid gap-2 px-4 py-3 sm:grid-cols-[minmax(0,1fr)_auto]">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-zinc-100">{job.task || "Untitled job"}</p>
              <div class="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-xs text-zinc-600">
                <span class="font-mono">{job.id}</span>
                <span :if={job.parent_session_id}>parent {job.parent_session_id}</span>
                <.link :if={job.child_session_id} navigate={~p"/sessions/#{job.child_session_id}"} class="text-orange-200 hover:underline">child {job.child_session_id}</.link>
                <span :if={job.model}>{job.model}</span>
                <span :if={job.duration_ms}>{job.duration_ms} ms</span>
              </div>
              <p :if={job.error} class="mt-2 text-xs text-red-200">{job.error}</p>
            </div>
            <.status_badge status={job.status || :running} />
          </div>
        </div>
      </section>
    </.app_shell>
    """
  end

  defp assign_jobs(socket) do
    jobs = Exy.Subagents.JobStore.list()

    socket
    |> assign(:jobs, jobs)
    |> assign(:job_count, length(jobs))
  end
end
