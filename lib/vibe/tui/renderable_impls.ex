defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.UserMessage do
  alias Vibe.TUI.RenderKey

  def render(message, context) do
    message
    |> Map.from_struct()
    |> Map.put(:role, :user)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(message, context) do
    RenderKey.component(
      :user_message,
      message.id,
      RenderKey.fingerprint({message.text, message.at}),
      context
    )
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.AssistantMessage do
  alias Vibe.TUI.RenderKey

  def render(message, context) do
    message
    |> Map.from_struct()
    |> Map.put(:role, :assistant)
    |> maybe_put_loader_phase(context)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(%{id: "streaming"} = message, context) do
    RenderKey.component(
      :assistant_message,
      message.id,
      RenderKey.fingerprint(message),
      [Keyword.get(context.opts, :loader_phase, 0)],
      context
    )
  end

  def render_key(message, context) do
    RenderKey.component(:assistant_message, message.id, RenderKey.fingerprint(message), context)
  end

  defp maybe_put_loader_phase(props, context) do
    if props.id == "streaming" do
      Map.put(props, :loader_phase, Keyword.get(context.opts, :loader_phase, 0))
    else
      props
    end
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.SystemMessage do
  alias Vibe.TUI.RenderKey

  def render(message, context) do
    message
    |> Map.from_struct()
    |> Map.put(:role, :system)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(message, context) do
    RenderKey.component(:system_message, message.id, RenderKey.fingerprint(message), context)
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.ToolCall do
  alias Vibe.TUI.RenderKey

  def render(tool, context) do
    tool
    |> Map.from_struct()
    |> Vibe.TUI.tool()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(tool, context) do
    RenderKey.component(
      :tool_call,
      tool.id,
      RenderKey.fingerprint({tool.args, tool.output, tool.output_parts}),
      [tool.name, tool.status, tool.expanded?, tool.truncate?, tool.output_format],
      context
    )
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.SubagentLifecycle do
  alias Vibe.TUI.RenderKey

  def render(event, context) do
    event
    |> Map.from_struct()
    |> Map.put(:role, :subagent)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(event, context) do
    RenderKey.component(:subagent_lifecycle, event.id, RenderKey.fingerprint(event), context)
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.PluginWidget do
  alias Vibe.TUI.RenderKey

  def render(widget, context) do
    widget
    |> Vibe.TUI.plugin_widget()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(widget, context) do
    RenderKey.component(
      :plugin_widget,
      widget.id,
      RenderKey.fingerprint(widget.props),
      [widget.type, widget.version, widget.placement],
      context
    )
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.NotificationList do
  alias Vibe.TUI.RenderKey

  def render(notifications, context) do
    notifications
    |> Vibe.TUI.notifications()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(notifications, context) do
    RenderKey.component(
      :notifications,
      :main,
      RenderKey.fingerprint(notifications.items),
      context
    )
  end
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.Footer do
  alias Vibe.TUI.RenderKey

  def render(footer, context) do
    footer
    |> Vibe.TUI.footer()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(footer, context) do
    RenderKey.component(:footer, :main, RenderKey.fingerprint(footer), context)
  end
end
