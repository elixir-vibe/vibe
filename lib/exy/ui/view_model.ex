defmodule Exy.UI.ViewModel do
  @moduledoc """
  Converts `Exy.UI.State` into semantic blocks for renderers.
  """

  alias Exy.Lists

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
          plugin_widgets: [PluginWidget.t()],
          title: String.t() | nil,
          working_message: String.t() | nil,
          hidden_thinking_label: String.t() | nil
        }

  @spec from_state(Exy.UI.State.t()) :: t()
  def from_state(state) do
    %{
      body:
        state
        |> message_blocks()
        |> Lists.join(streaming_blocks(state))
        |> Lists.join(tool_blocks(state)),
      footer: %Footer{
        cwd: state.cwd,
        model: state.model,
        session_id: state.session_id,
        status: state.status,
        usage: state.usage,
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

  defp message_blocks(state) do
    state.messages
    |> Enum.with_index()
    |> Enum.map(fn {message, index} ->
      id = "message-#{index}"

      case message.role do
        :user -> %UserMessage{id: id, text: message.text, at: message.at}
        :assistant -> assistant_block(id, message)
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

  defp streaming_blocks(%{streaming_message: nil}), do: []

  defp streaming_blocks(%{streaming_message: message}) do
    [
      %AssistantMessage{id: "streaming", text: Map.get(message, :text), at: Map.get(message, :at)}
      |> Map.put(:role, :assistant)
    ]
  end

  defp notification_block([]), do: nil
  defp notification_block(items), do: %NotificationList{items: items}

  defp plugin_widgets(widgets) do
    widgets
    |> Enum.sort_by(fn {key, _widget} -> to_string(key) end)
    |> Enum.map(fn {key, widget} ->
      %PluginWidget{
        key: key,
        content: Map.get(widget, :content, []),
        placement: Map.get(widget, :placement, :above_editor)
      }
    end)
  end

  defp tool_blocks(state) do
    state.pending_tools
    |> Map.values()
    |> Enum.map(fn tool ->
      %ToolCall{
        id: tool.id,
        name: Map.get(tool, :name),
        status: Map.get(tool, :status),
        args: Map.get(tool, :args),
        output: Map.get(tool, :output),
        expanded?: Map.get(tool, :expanded?, false)
      }
    end)
  end
end
