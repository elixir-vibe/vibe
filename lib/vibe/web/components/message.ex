defmodule Vibe.Web.Components.Message do
  @moduledoc "Conversation message components for Vibe Web."
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: Vibe.Web.Endpoint,
    router: Vibe.Web.Router,
    statics: Vibe.Web.static_paths()

  import Vibe.Web.Components.Tool, only: [tool_card: 1]

  alias Vibe.UI.Error

  attr(:message, :map, required: true)

  def message_card(%{message: %{role: role}} = assigns) when role in [:tool, "tool"] do
    ~H"""
    <.tool_card tool={@message} />
    """
  end

  def message_card(assigns) do
    ~H"""
    <article class={[
      "max-w-full px-3 py-2 text-sm leading-6 sm:px-4",
      if(@message.role == :user,
        do: "rounded-lg border border-vibe-accent/20 bg-vibe-accent/[0.07] text-vibe-fg-strong sm:ml-auto sm:max-w-[82%]",
        else: "border-l-2 border-vibe-accent/25 text-vibe-fg-strong"
      )
    ]}>
      <div :if={@message.role == :user} class="space-y-2">
        <div class="whitespace-pre-wrap break-words font-sans [overflow-wrap:anywhere]">{message_text(@message)}</div>
        <div :if={image_count(@message) > 0} class="inline-flex items-center rounded-full border border-vibe-accent/20 bg-vibe-accent/10 px-2 py-0.5 text-xs text-vibe-accent-strong/80">
          {image_count(@message)} {if image_count(@message) == 1, do: "image", else: "images"} attached
        </div>
      </div>
      <pre :if={@message.role != :user and preformatted_message?(message_text(@message))} class="whitespace-pre-wrap break-words font-mono text-sm leading-6 text-vibe-fg-strong [overflow-wrap:anywhere]">{message_text(@message)}</pre>
      <PhoenixStreamdown.markdown
        :if={@message.role != :user and !preformatted_message?(message_text(@message))}
        id={message_dom_id(@message)}
        content={message_text(@message)}
        streaming={Map.get(@message, :streaming?, false)}
        animate="fadeIn"
        class="vibe-markdown"
        mdex_opts={[render: [unsafe: false]]}
      />
    </article>
    """
  end

  defp preformatted_message?(text) do
    String.contains?(text, "\n") and not markdown_block?(text)
  end

  defp markdown_block?(text) do
    Regex.match?(~r/(^|\n)\s{0,3}(\#{1,6}\s|[-*+]\s|\d+\.\s|```|~~~|>\s)/, text)
  end

  defp message_dom_id(message) do
    Map.get(message, :dom_id) ||
      "message-#{:erlang.phash2({message[:role], message_text(message)})}"
  end

  defp image_count(message) do
    case Map.get(message, :image_count, 0) do
      count when is_integer(count) and count > 0 -> count
      _count -> 0
    end
  end

  defp message_text(%{text: text}) when is_binary(text), do: text
  defp message_text(%{result: %{output: output}}) when is_binary(output), do: output
  defp message_text(%{result: %{"output" => output}}) when is_binary(output), do: output
  defp message_text(%{result: result}), do: inspect(result, pretty: true, limit: 40)
  defp message_text(%{error: error}), do: Error.text(error)
  defp message_text(message), do: inspect(message, pretty: true, limit: 40)
end
