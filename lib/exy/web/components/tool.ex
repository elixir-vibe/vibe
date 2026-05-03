defmodule Exy.Web.Components.Tool do
  @moduledoc "Tool result components for Exy Web."
  use Phoenix.Component

  alias Exy.Web.Components.Code

  attr(:tool, :map, required: true)

  def tool_card(assigns) do
    assigns = assign(assigns, :display, Exy.Tool.Display.from_tool(assigns.tool))

    ~H"""
    <article class="overflow-hidden rounded-lg border border-violet-300/15 bg-[#15131b]/70">
      <header class="flex min-w-0 flex-col gap-2 px-3 py-2 sm:flex-row sm:items-start sm:justify-between sm:px-4">
        <div class="min-w-0">
          <div class="flex min-w-0 flex-wrap items-center gap-2">
            <h3 class="text-sm font-semibold text-zinc-100">{tool_name(@display.name)}</h3>
            <Exy.Web.Components.Core.status_badge :if={(@display.status || @tool.status) not in [:ok, "ok"]} status={@display.status || @tool.status || :running} />
          </div>
          <div :if={display_text(@display.summary) not in [nil, ""]} class="mt-1 break-words font-mono text-xs leading-5 text-zinc-500 [overflow-wrap:anywhere]">
            <%= if @display.summary_style == :elixir_dim do %>
              {Phoenix.HTML.raw(Code.summary_html(display_text(@display.summary)))}
            <% else %>
              {display_text(@display.summary)}
            <% end %>
          </div>
        </div>
        <div :if={@display.meta != []} class="flex shrink-0 flex-wrap gap-1 text-xs text-zinc-500">
          <span :for={meta <- @display.meta} class="rounded bg-white/[0.035] px-1.5 py-0.5">{display_text(meta)}</span>
        </div>
      </header>

      <div class="space-y-2 px-3 pb-3 sm:px-4">
        <%= if @display.body == [] do %>
          <p class="text-sm text-zinc-500">No tool output.</p>
        <% else %>
          <%= for block <- @display.body do %>
            <.tool_body_block block={block} truncate?={false} />
          <% end %>
        <% end %>
      </div>
    </article>
    """
  end

  attr(:block, :any, required: true)
  attr(:truncate?, :boolean, default: true)

  def tool_body_block(assigns) do
    assigns = assign(assigns, :body, block_body(assigns.block, assigns.truncate?))

    ~H"""
    <section class="overflow-hidden rounded-md bg-[#0d0c11]/72 ring-1 ring-white/8">
      <div :if={@body.label not in [nil, "", "Output", "Inspect"]} class="border-b border-white/8 px-3 py-1.5 text-[0.62rem] font-semibold uppercase tracking-[0.18em] text-zinc-600">{@body.label}</div>

      <div :if={@body.kind in [:markdown, :source_html, :diff_html]} class="max-h-[28rem] overflow-auto px-3 py-2 text-sm leading-6 text-zinc-200 [overflow-wrap:anywhere] [&_a]:text-orange-200 [&_a]:underline [&_blockquote]:border-l-2 [&_blockquote]:border-orange-300/30 [&_blockquote]:pl-3 [&_blockquote]:text-zinc-300 [&_code]:rounded [&_code]:bg-white/[0.06] [&_code]:px-1 [&_h1]:text-xl [&_h2]:text-lg [&_h3]:text-base [&_li]:ml-5 [&_ol]:list-decimal [&_p+p]:mt-3 [&_pre]:overflow-auto [&_pre]:rounded-md [&_pre]:bg-transparent [&_table]:w-full [&_table]:border-collapse [&_td]:border [&_td]:border-white/10 [&_td]:px-2 [&_td]:py-1 [&_th]:border [&_th]:border-white/10 [&_th]:px-2 [&_th]:py-1 [&_ul]:list-disc">
        {Phoenix.HTML.raw(@body.html)}
      </div>

      <figure :if={@body.kind == :image} class="space-y-2 px-3 py-2">
        <img class="max-h-[32rem] max-w-full rounded border border-white/10 object-contain" src={@body.src} alt={@body.alt} />
        <figcaption class="font-mono text-[0.68rem] leading-4 text-zinc-500">{@body.caption}</figcaption>
      </figure>

      <pre :if={@body.kind not in [:markdown, :source_html, :diff_html, :image]} class={[
        "max-h-[28rem] overflow-auto whitespace-pre-wrap break-words px-3 py-2 text-xs leading-5 [overflow-wrap:anywhere]",
        if(@body.kind == :error, do: "text-red-200", else: "text-zinc-200"),
        if(@body.mono?, do: "font-mono", else: "font-sans")
      ]}>{@body.text}</pre>
    </section>
    """
  end

  defp tool_name(name) when is_atom(name), do: name |> Atom.to_string() |> String.capitalize()
  defp tool_name(name) when is_binary(name), do: String.capitalize(name)
  defp tool_name(_name), do: "Tool"

  defp block_body({:markdown, text, _opts}, truncate?) do
    text = text |> display_text() |> truncate_text(truncate?)
    %{kind: :markdown, label: "Markdown", html: Code.markdown_html(text), mono?: false}
  end

  defp block_body({:source, text, opts}, truncate?) do
    language = opts |> Keyword.get(:language, :text) |> to_string()
    text = text |> display_text() |> truncate_text(truncate?)

    %{
      kind: :source_html,
      label: String.upcase(language),
      html: Code.source_html(text, language),
      mono?: true
    }
  end

  defp block_body({:diff, text, _opts}, truncate?) do
    %{
      kind: :diff_html,
      label: "Diff",
      html: Code.diff_html(text |> display_text() |> truncate_text(truncate?)),
      mono?: true
    }
  end

  defp block_body({:inspect, text, _opts}, truncate?),
    do: text_block(:inspect, "Inspect", text, truncate?)

  defp block_body({:error, text, _opts}, truncate?),
    do: text_block(:error, "Error", text, truncate?)

  defp block_body({:text, text, _opts}, truncate?),
    do: text_block(:text, "Output", text, truncate?)

  defp block_body({:image, %Exy.Model.Content.Image{} = image, _opts}, _truncate?) do
    caption =
      [image.filename, image.mime_type, image_size(image)]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" · ")

    %{
      kind: :image,
      label: "Image",
      src: "data:#{image.mime_type};base64,#{image.data}",
      alt: image.filename || "Image",
      caption: caption,
      mono?: false
    }
  end

  defp block_body({:lines, lines, _opts}, truncate?) do
    text = lines |> rendered_lines() |> Enum.map_join("\n", &display_text/1)
    %{kind: :text, label: "Output", text: truncate_text(text, truncate?), mono?: true}
  end

  defp block_body(block, truncate?) do
    %{
      kind: :inspect,
      label: "Output",
      text: block |> inspect(pretty: true) |> truncate_text(truncate?),
      mono?: true
    }
  end

  defp image_size(%{width: width, height: height}) when is_integer(width) and is_integer(height),
    do: "#{width}×#{height}"

  defp image_size(_image), do: nil

  defp text_block(kind, label, text, truncate?) do
    %{
      kind: kind,
      label: label,
      text: text |> display_text() |> truncate_text(truncate?),
      mono?: true
    }
  end

  defp rendered_lines(nil), do: []
  defp rendered_lines(lines) when is_list(lines), do: lines
  defp rendered_lines(line), do: [line]

  defp display_text(value), do: Code.display_text(value)
  defp truncate_text(text, false), do: text
  defp truncate_text(nil, _truncate?), do: ""
  defp truncate_text(text, true), do: text
end
