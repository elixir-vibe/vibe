defmodule Exy.UI.ViewModel do
  @moduledoc """
  Converts `Exy.UI.State` into semantic blocks for renderers.
  """

  alias Exy.{Lists, LLM.Usage}

  alias Exy.UI.Block.{
    AssistantMessage,
    Footer,
    NotificationList,
    Overlay,
    PluginWidget,
    ToolCall,
    UserMessage
  }

  @type t :: %{
          body: [struct()],
          footer: Footer.t(),
          overlays: [Overlay.t()],
          notifications: NotificationList.t() | nil,
          plugin_widgets: %{
            above_editor: [PluginWidget.t()],
            below_editor: [PluginWidget.t()],
            sidebar: [PluginWidget.t()]
          },
          title: String.t() | nil,
          working_message: String.t() | nil,
          hidden_thinking_label: String.t() | nil
        }

  @spec from_state(Exy.UI.State.t()) :: t()
  def from_state(state) do
    %{
      body: state |> message_blocks() |> Lists.join(loader_blocks(state)),
      footer: %Footer{
        cwd: state.cwd,
        model: state.model,
        session_id: state.session_id,
        status: state.status,
        usage: visible_usage(state),
        active_sessions: state.active_sessions,
        plugin_statuses: state.plugin_statuses
      },
      overlays: Enum.map(state.overlays, &%Overlay{kind: &1.kind, data: &1}),
      notifications: notification_block(state.notifications),
      plugin_widgets: plugin_widgets(state.plugin_widgets),
      title: state.title,
      working_message: state.working_message,
      hidden_thinking_label: state.hidden_thinking_label
    }
  end

  defp visible_usage(state), do: Usage.summarize([state.usage, state.usage_preview])

  defp message_blocks(state) do
    state.messages
    |> Enum.with_index()
    |> Enum.map(fn {message, index} ->
      id = "message-#{index}"

      case message.role do
        :user -> %UserMessage{id: id, text: message.text, at: message.at}
        :assistant -> assistant_block(id, message)
        :tool -> tool_block(message, state)
      end
      |> Map.put(:role, message.role)
    end)
  end

  defp assistant_block(id, message) do
    %AssistantMessage{
      id: id,
      text: Map.get(message, :text) || result_text(Map.get(message, :result)),
      error: Map.get(message, :error),
      result: Map.get(message, :result),
      at: message.at
    }
  end

  defp result_text(nil), do: nil
  defp result_text(%{output: output}), do: result_text(output)
  defp result_text(%{message: %{content: content}}), do: content_text(content)
  defp result_text(result) when is_binary(result), do: result
  defp result_text(result), do: inspect(result, pretty: true, limit: 20)

  defp content_text(content) when is_list(content) do
    content
    |> Enum.map(fn
      %{type: :text, text: text} -> text
      %{type: "text", text: text} -> text
      %{text: text} -> text
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
  end

  defp content_text(_content), do: nil

  defp loader_blocks(%{streaming_message: nil}), do: []

  defp loader_blocks(state) do
    case List.last(state.messages) do
      %{role: :assistant, text: text} when is_binary(text) and text != "" ->
        []

      _message ->
        [
          %AssistantMessage{id: "streaming", text: "", at: state.streaming_message[:at]}
          |> Map.put(:role, :assistant)
        ]
    end
  end

  defp notification_block([]), do: nil
  defp notification_block(items), do: %NotificationList{items: items}

  defp plugin_widgets(widgets) do
    widgets
    |> Enum.sort_by(fn {id, _widget} -> to_string(id) end)
    |> Enum.map(fn {_id, widget} ->
      widget = Exy.UI.Widget.normalize(widget)

      %PluginWidget{
        id: widget.id,
        type: widget.type,
        props: widget.props,
        placement: widget.placement,
        version: widget.version
      }
    end)
    |> Enum.group_by(& &1.placement)
    |> then(fn groups ->
      %{
        above_editor: Map.get(groups, :above_editor, []),
        below_editor: Map.get(groups, :below_editor, []),
        sidebar: Map.get(groups, :sidebar, [])
      }
    end)
  end

  defp tool_block(tool, state) do
    %ToolCall{
      id: tool.id,
      name: Map.get(tool, :name),
      status: Map.get(tool, :status),
      args: Map.get(tool, :args),
      output: Map.get(tool, :output),
      expanded?: Map.get(tool, :expanded?, false),
      truncate?: state.truncate?
    }
  end
end
