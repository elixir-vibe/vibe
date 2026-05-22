defmodule Vibe.Web.Presentation.Tool.BodyProjection do
  @moduledoc false

  alias Vibe.Files.{Artifacts, ImageRef}
  alias Vibe.Model.Content
  alias Vibe.Web.Components.Code

  defmodule Body do
    @moduledoc false
    defstruct [
      :alt,
      :caption,
      :html,
      :kind,
      :label,
      :original_url,
      :src,
      :text,
      collapsible?: false,
      mono?: false
    ]
  end

  @spec block(term(), boolean()) :: %Body{}
  def block({:markdown, text, _opts}, truncate?) do
    text = text |> Code.display_text() |> truncate_text(truncate?)
    %Body{kind: :markdown, label: "Markdown", html: Code.markdown_html(text), mono?: false}
  end

  def block({:source, text, opts}, truncate?) do
    language = opts |> Keyword.get(:language, :text) |> to_string()
    text = text |> Code.display_text() |> truncate_text(truncate?)

    %Body{
      kind: :source_html,
      label: String.upcase(language),
      html: Code.source_html(text, language),
      mono?: true
    }
  end

  def block({:diff, text, _opts}, truncate?) do
    %Body{
      kind: :diff_html,
      label: "Diff",
      html: Code.diff_html(text |> Code.display_text() |> truncate_text(truncate?)),
      mono?: true
    }
  end

  def block({:inspect, text, _opts}, truncate?),
    do: text_block(:inspect, "Inspect", text, truncate?)

  def block({:error, text, _opts}, truncate?), do: text_block(:error, "Error", text, truncate?)
  def block({:text, text, _opts}, truncate?), do: text_block(:text, "Output", text, truncate?)
  def block({:image, %Content.Image{} = image, _opts}, _truncate?), do: image_body(image)
  def block({:image_ref, %ImageRef{} = ref, _opts}, _truncate?), do: image_body(ref)

  def block({:lines, lines, _opts}, truncate?) do
    text = lines |> rendered_lines() |> Enum.map_join("\n", &Code.display_text/1)
    %Body{kind: :text, label: "Output", text: truncate_text(text, truncate?), mono?: true}
  end

  def block(block, truncate?) do
    %Body{
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

    %Body{
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

  defp image_src(%ImageRef{} = ref),
    do: Artifacts.public_path(ref) || "data:#{ref.mime_type};base64,#{ref.data}"

  defp original_url(%ImageRef{} = ref), do: Artifacts.public_path(ref)
  defp original_url(_image), do: nil

  defp image_size(%{width: width, height: height}) when is_integer(width) and is_integer(height),
    do: "#{width}×#{height}"

  defp image_size(_image), do: nil

  defp byte_size_label(%{size_bytes: bytes}) when is_integer(bytes), do: Vibe.Format.bytes(bytes)

  defp byte_size_label(%Content.Image{data: data}) when is_binary(data),
    do: data |> byte_size() |> Vibe.Format.bytes()

  defp byte_size_label(_image), do: nil

  defp collapsible_image?(%{size_bytes: bytes}) when is_integer(bytes), do: bytes >= 500_000

  defp collapsible_image?(%Content.Image{data: data}) when is_binary(data),
    do: byte_size(data) >= 500_000

  defp collapsible_image?(_image), do: false

  defp text_block(kind, label, text, truncate?) do
    %Body{
      kind: kind,
      label: label,
      text: text |> Code.display_text() |> truncate_text(truncate?),
      mono?: true
    }
  end

  defp rendered_lines(nil), do: []
  defp rendered_lines(lines) when is_list(lines), do: lines
  defp rendered_lines(line), do: [line]
  defp truncate_text(text, false), do: text
  defp truncate_text(nil, _truncate?), do: ""
  defp truncate_text(text, true), do: text
end
