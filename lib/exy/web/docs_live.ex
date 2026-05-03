defmodule Exy.Web.DocsLive do
  @moduledoc "LiveView browser for built-in Exy documentation."
  use Exy.Web, :live_view

  alias Exy.Docs

  @impl true
  def mount(params, _session, socket) do
    {:ok, assign_docs(socket, Map.get(params, "topic", "quickstart"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, assign_docs(socket, Map.get(params, "topic", "quickstart"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.app_shell current={:docs} title={@title} subtitle={@subtitle}>
      <:sidebar>
        <.panel title="Topics">
          <nav class="space-y-1" aria-label="Documentation topics">
            <.link :for={topic <- @topics} navigate={~p"/docs/#{topic.name}"} class={[
              "block rounded-md px-2 py-1.5 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-orange-300/70",
              if(topic.name == @topic, do: "bg-white/10 text-white", else: "text-zinc-400 hover:bg-white/5 hover:text-zinc-100")
            ]}>
              {topic.title}
            </.link>
          </nav>
        </.panel>
      </:sidebar>

      <section class="rounded-xl border border-white/[0.07] bg-[#121016]/60 px-4 py-4 sm:px-6 sm:py-5">
        <PhoenixStreamdown.markdown
          id={"docs-#{@topic}"}
          content={@markdown}
          streaming={false}
          class="exy-markdown"
          mdex_opts={[render: [unsafe: false]]}
        />
      </section>
    </.app_shell>
    """
  end

  defp assign_docs(socket, topic) do
    normalized = normalize_topic(topic)

    topics = Docs.topics()
    title = topic_title(topics, normalized)
    markdown = Docs.render(normalized)

    socket
    |> assign(:topics, topics)
    |> assign(:topic, normalized)
    |> assign(:title, title)
    |> assign(:subtitle, "Built-in Exy docs · #{normalized}")
    |> assign(:markdown, strip_matching_title(markdown, title))
  end

  defp normalize_topic(nil), do: "quickstart"
  defp normalize_topic(""), do: "quickstart"

  defp normalize_topic(topic) do
    topic
    |> to_string()
    |> String.trim()
    |> String.trim_leading("/")
    |> String.downcase()
  end

  defp topic_title(topics, topic) do
    topics
    |> Enum.find_value(fn candidate -> candidate.name == topic && candidate.title end)
    |> Kernel.||("Docs")
  end

  defp strip_matching_title(markdown, title) do
    pattern = ~r/^\s*#\s+#{Regex.escape(title)}\s*\n+/i
    String.replace(markdown, pattern, "", global: false)
  end
end
