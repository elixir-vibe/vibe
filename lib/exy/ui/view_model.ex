defmodule Exy.UI.ViewModel do
  @moduledoc """
  Converts `Exy.UI.State` into semantic blocks for renderers.
  """

  alias Exy.Lists
  alias Exy.UI.Block.{AssistantMessage, Footer, Overlay, ToolCall, UserMessage}

  @type t :: %{
          body: [struct()],
          footer: Footer.t(),
          overlays: [Overlay.t()]
        }

  @spec from_state(Exy.UI.State.t()) :: t()
  def from_state(state) do
    %{
      body: Lists.join(message_blocks(state), tool_blocks(state)),
      footer: %Footer{
        cwd: state.cwd,
        model: state.model,
        session_id: state.session_id,
        status: state.status,
        usage: state.usage
      },
      overlays: Enum.map(state.overlays, &%Overlay{kind: &1.kind, data: &1})
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
