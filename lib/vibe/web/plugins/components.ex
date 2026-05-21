defmodule Vibe.Web.Plugins.Components do
  @moduledoc "Components for rendering plugin-owned UI documents."
  use Phoenix.Component

  attr(:widget, Vibe.Presentation.Widget, required: true)

  def plugin_ui_widget(%{widget: %{type: :markdown}} = assigns) do
    assigns = assign(assigns, :content, get_in(assigns.widget.props, [:content]) || "")

    ~H"""
    <PhoenixStreamdown.markdown id={"plugin-ui-#{@widget.id}"} content={@content} streaming={false} class="vibe-markdown" mdex_opts={[render: [unsafe: false]]} />
    """
  end

  def plugin_ui_widget(%{widget: %{type: :lines}} = assigns) do
    assigns =
      assign(assigns, :content, assigns.widget.props |> Map.get(:content, []) |> Enum.join("\n"))

    ~H"""
    <p class="whitespace-pre-wrap text-sm leading-6 text-vibe-fg">{@content}</p>
    """
  end

  def plugin_ui_widget(%{widget: %{type: :progress}} = assigns) do
    assigns = assign(assigns, :props, assigns.widget.props)

    ~H"""
    <div class="rounded-md bg-vibe-surface-muted/35 p-3 text-sm text-vibe-fg">
      <div class="flex justify-between gap-3">
        <span>{Map.get(@props, :title) || "Progress"}</span>
        <span class="font-mono text-vibe-dim">{Map.get(@props, :current, 0)} / {Map.get(@props, :total, "?")}</span>
      </div>
      <p :if={Map.get(@props, :message)} class="mt-1 text-xs text-vibe-dim">{Map.get(@props, :message)}</p>
    </div>
    """
  end

  def plugin_ui_widget(assigns) do
    assigns = assign(assigns, :text, inspect(assigns.widget.props, pretty: true, limit: 40))

    ~H"""
    <pre class="overflow-auto whitespace-pre-wrap rounded-md bg-vibe-code p-3 font-mono text-xs leading-5 text-vibe-muted">{@text}</pre>
    """
  end
end
