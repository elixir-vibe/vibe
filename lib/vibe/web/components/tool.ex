defmodule Vibe.Web.Components.Tool do
  @moduledoc "Tool result components for Vibe Web."
  use Phoenix.Component

  alias Vibe.Files.{Artifacts, ImageRef}
  alias Vibe.Model.Content
  alias Vibe.Tool.Display
  alias Vibe.Web.Components.Code

  attr(:tool, :map, required: true)

  def tool_card(assigns) do
    assigns = assign(assigns, :display, Display.from_tool(assigns.tool))

    ~H"""
    <article class="overflow-hidden rounded-lg border border-vibe-accent/15 bg-vibe-surface/70">
      <header class="flex min-w-0 flex-col gap-2 px-3 py-2 sm:flex-row sm:items-start sm:justify-between sm:px-4">
        <div class="min-w-0">
          <div class="flex min-w-0 flex-wrap items-center gap-2">
            <h3 class="text-sm font-semibold text-vibe-fg-strong">{tool_name(@display.name)}</h3>
            <Vibe.Web.Components.Core.status_badge :if={(@display.status || @tool.status) not in [:ok, "ok"]} status={@display.status || @tool.status || :running} />
          </div>
          <div :if={display_text(@display.summary) not in [nil, ""]} class="mt-1 break-words font-mono text-xs leading-5 text-vibe-dim [overflow-wrap:anywhere]">
            <%= if @display.summary_style == :elixir_dim do %>
              {Phoenix.HTML.raw(Code.summary_html(display_text(@display.summary)))}
            <% else %>
              {display_text(@display.summary)}
            <% end %>
          </div>
        </div>
        <div :if={@display.meta != []} class="flex shrink-0 flex-wrap gap-1 text-xs text-vibe-dim">
          <span :for={meta <- @display.meta} class="rounded bg-vibe-surface-muted/35 px-1.5 py-0.5">{display_text(meta)}</span>
        </div>
      </header>

      <div class="space-y-2 px-3 pb-3 sm:px-4">
        <%= if @display.body == [] do %>
          <p class="text-sm text-vibe-dim">No tool output.</p>
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
    <section class="overflow-hidden rounded-md bg-vibe-bg/72 ring-1 ring-white/8">
      <div :if={@body.label not in [nil, "", "Output", "Inspect"]} class="border-b border-vibe-border/40 px-3 py-1.5 text-[0.62rem] font-semibold uppercase tracking-[0.18em] text-vibe-dim">{@body.label}</div>

      <div :if={@body.kind in [:markdown, :source_html, :diff_html]} class="max-h-[28rem] overflow-auto px-3 py-2 text-sm leading-6 text-vibe-fg [overflow-wrap:anywhere] [&_a]:text-vibe-accent-strong [&_a]:underline [&_blockquote]:border-l-2 [&_blockquote]:border-vibe-accent/30 [&_blockquote]:pl-3 [&_blockquote]:text-vibe-fg [&_code]:rounded [&_code]:bg-vibe-surface-strong [&_code]:px-1 [&_h1]:text-xl [&_h2]:text-lg [&_h3]:text-base [&_li]:ml-5 [&_ol]:list-decimal [&_p+p]:mt-3 [&_pre]:overflow-auto [&_pre]:rounded-md [&_pre]:bg-transparent [&_table]:w-full [&_table]:border-collapse [&_td]:border [&_td]:border-vibe-border/50 [&_td]:px-2 [&_td]:py-1 [&_th]:border [&_th]:border-vibe-border/50 [&_th]:px-2 [&_th]:py-1 [&_ul]:list-disc">
        {Phoenix.HTML.raw(@body.html)}
      </div>

      <figure :if={@body.kind == :image} class="space-y-2 px-3 py-2">
        <details :if={@body.collapsible?} class="group" open>
          <summary class="cursor-pointer select-none pb-2 text-xs text-vibe-dim marker:text-vibe-dim">Image preview</summary>
          <img class="max-h-[32rem] max-w-full rounded border border-vibe-border/50 object-contain" src={@body.src} alt={@body.alt} loading="lazy" />
        </details>
        <img :if={!@body.collapsible?} class="max-h-[32rem] max-w-full rounded border border-vibe-border/50 object-contain" src={@body.src} alt={@body.alt} loading="lazy" />
        <figcaption class="flex flex-wrap items-center gap-x-2 gap-y-1 font-mono text-[0.68rem] leading-4 text-vibe-dim">
          <span>{@body.caption}</span>
          <a :if={@body.original_url} class="text-vibe-accent-strong underline decoration-vibe-accent-strong/40 hover:text-vibe-accent-strong" href={@body.original_url} target="_blank" rel="noopener">Open original</a>
        </figcaption>
      </figure>

      <pre :if={@body.kind not in [:markdown, :source_html, :diff_html, :image]} class={[
        "max-h-[28rem] overflow-auto whitespace-pre-wrap break-words px-3 py-2 text-xs leading-5 [overflow-wrap:anywhere]",
        if(@body.kind == :error, do: "text-vibe-error", else: "text-vibe-fg"),
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

  defp block_body({:image, %Content.Image{} = image, _opts}, _truncate?), do: image_body(image)
  defp block_body({:image_ref, %ImageRef{} = ref, _opts}, _truncate?), do: image_body(ref)

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

  defp image_body(image) do
    caption =
      [image.filename, image.mime_type, image_size(image), byte_size_label(image)]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" · ")

    %{
      kind: :image,
      label: "Image",
      src: image_src(image),
      alt: image.filename || "Image",
      caption: caption,
      original_url: original_url(image),
      collapsible?: collapsible_image?(image),
      mono?: false
    }
  end

  defp image_src(%Content.Image{} = image), do: "data:#{image.mime_type};base64,#{image.data}"

  defp image_src(%ImageRef{} = ref) do
    Artifacts.public_path(ref) || "data:#{ref.mime_type};base64,#{ref.data}"
  end

  defp original_url(%ImageRef{} = ref), do: Artifacts.public_path(ref)
  defp original_url(_image), do: nil

  defp image_size(%{width: width, height: height}) when is_integer(width) and is_integer(height),
    do: "#{width}×#{height}"

  defp image_size(_image), do: nil

  defp byte_size_label(%{size_bytes: bytes}) when is_integer(bytes), do: format_bytes(bytes)

  defp byte_size_label(%Content.Image{data: data}) when is_binary(data),
    do: data |> byte_size() |> format_bytes()

  defp byte_size_label(_image), do: nil

  defp collapsible_image?(%{size_bytes: bytes}) when is_integer(bytes), do: bytes >= 500_000

  defp collapsible_image?(%Content.Image{data: data}) when is_binary(data),
    do: byte_size(data) >= 500_000

  defp collapsible_image?(_image), do: false

  defp format_bytes(bytes) when bytes >= 1_000_000, do: "#{Float.round(bytes / 1_000_000, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_000, do: "#{Float.round(bytes / 1_000, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"

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
