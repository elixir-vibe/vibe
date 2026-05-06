defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.UserMessage do
  def render(message, context) do
    message
    |> Map.from_struct()
    |> Map.put(:role, :user)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(message, context) do
    {:user_message, message.id, hash({message.text, message.at}), context.width,
     context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.AssistantMessage do
  def render(message, context) do
    message
    |> Map.from_struct()
    |> Map.put(:role, :assistant)
    |> maybe_put_loader_phase(context)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(%{id: "streaming"} = message, context) do
    {:assistant_message, message.id, hash(message), Keyword.get(context.opts, :loader_phase, 0),
     context.width, context.theme.name}
  end

  def render_key(message, context) do
    {:assistant_message, message.id, hash(message), context.width, context.theme.name}
  end

  defp maybe_put_loader_phase(props, context) do
    if props.id == "streaming" do
      Map.put(props, :loader_phase, Keyword.get(context.opts, :loader_phase, 0))
    else
      props
    end
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.SystemMessage do
  def render(message, context) do
    message
    |> Map.from_struct()
    |> Map.put(:role, :system)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(message, context) do
    {:system_message, message.id, hash(message), context.width, context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.ToolCall do
  def render(tool, context) do
    tool
    |> Map.from_struct()
    |> Vibe.TUI.tool()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(tool, context) do
    {:tool_call, tool.id, tool.name, tool.status, tool.expanded?, tool.truncate?, hash(tool.args),
     hash(tool.output), hash(tool.output_parts), tool.output_format, context.width,
     context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.SubagentLifecycle do
  def render(event, context) do
    event
    |> Map.from_struct()
    |> Map.put(:role, :subagent)
    |> Vibe.TUI.message()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(event, context) do
    {:subagent_lifecycle, event.id, hash(event), context.width, context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.PluginWidget do
  def render(widget, context) do
    widget
    |> Vibe.TUI.plugin_widget()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(widget, context) do
    {:plugin_widget, widget.id, widget.type, widget.version, hash(widget.props), widget.placement,
     context.width, context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.NotificationList do
  def render(notifications, context) do
    notifications
    |> Vibe.TUI.notifications()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(notifications, context) do
    {:notifications, hash(notifications.items), context.width, context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end

defimpl Vibe.TUI.Renderable, for: Vibe.UI.Block.Footer do
  def render(footer, context) do
    footer
    |> Vibe.TUI.footer()
    |> Vibe.TUI.Widget.render(context.width, context.theme)
  end

  def render_key(footer, context) do
    {:footer, hash(footer), context.width, context.theme.name}
  end

  defp hash(value), do: :erlang.phash2(value)
end
