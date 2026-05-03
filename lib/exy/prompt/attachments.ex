defmodule Exy.Prompt.Attachments do
  @moduledoc "Parses lightweight prompt file attachments such as `@image.png`."

  alias Exy.Image
  alias Exy.Model.Content

  @attachment_pattern ~r/(^|\s)@(?:"([^"]+)"|'([^']+)'|([^\s]+))/

  @type processed :: %{text: String.t(), images: [Content.Image.t()]}

  @spec process_file_args([String.t()], keyword()) :: {:ok, processed()} | {:error, term()}
  def process_file_args(file_args, opts \\ []) when is_list(file_args) do
    root = Keyword.get_lazy(opts, :root, &File.cwd!/0)

    file_args
    |> Enum.reduce_while({:ok, %{text: "", images: []}}, fn raw_path, {:ok, acc} ->
      path = resolve(raw_path, root)

      cond do
        not File.regular?(path) ->
          {:halt, {:error, {:file_not_found, path}}}

        Image.supported?(path) ->
          case Image.from_file(path, resize?: Keyword.get(opts, :resize?, true)) do
            {:ok, image} ->
              note = image_note(path, image)
              content = image_content(image)
              {:cont, {:ok, %{acc | text: acc.text <> note, images: [content | acc.images]}}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        true ->
          case File.read(path) do
            {:ok, content} ->
              {:cont,
               {:ok, %{acc | text: acc.text <> file_block(path, content), images: acc.images}}}

            {:error, reason} ->
              {:halt, {:error, {reason, path}}}
          end
      end
    end)
  end

  @spec build_initial(String.t(), [String.t()], keyword()) ::
          {:ok, String.t() | [Content.t()]} | {:error, term()}
  def build_initial(prompt, file_args, opts \\ [])
      when is_binary(prompt) and is_list(file_args) do
    with {:ok, %{text: file_text, images: images}} <- process_file_args(file_args, opts) do
      text = file_text <> prompt

      if images == [] do
        {:ok, text}
      else
        {:ok, [Content.text(text) | Enum.reverse(images)]}
      end
    end
  end

  @spec expand(String.t(), keyword()) :: String.t() | [Content.t()]
  def expand(prompt, opts \\ []) when is_binary(prompt) do
    root = Keyword.get_lazy(opts, :root, &File.cwd!/0)

    case attachments(prompt, root) do
      [] ->
        prompt

      attachments ->
        text =
          Regex.replace(@attachment_pattern, prompt, fn full,
                                                        prefix,
                                                        double_quoted,
                                                        single_quoted,
                                                        unquoted ->
            raw_path = attachment_path([double_quoted, single_quoted, unquoted])
            if image_attachment?(raw_path, root), do: prefix, else: full
          end)

        [Content.text(String.trim(text)) | Enum.map(attachments, &image_content/1)]
        |> Enum.reject(&empty_text?/1)
    end
  end

  @spec attachments(String.t(), Path.t()) :: [Path.t()]
  def attachments(prompt, root) when is_binary(prompt) and is_binary(root) do
    @attachment_pattern
    |> Regex.scan(prompt)
    |> Enum.map(fn [_match, _prefix | rest] -> attachment_path(rest) end)
    |> Enum.filter(&image_attachment?(&1, root))
    |> Enum.map(&resolve(&1, root))
  end

  defp attachment_path(captures), do: Enum.find(captures, &(&1 not in [nil, ""]))

  defp image_attachment?(raw_path, root) when is_binary(raw_path) do
    path = resolve(raw_path, root)
    File.regular?(path) and Image.supported?(path)
  end

  defp image_attachment?(_raw_path, _root), do: false

  defp image_content(path) when is_binary(path) do
    {:ok, image} = Image.from_file(path, resize?: true)
    image_content(image)
  end

  defp image_content(%Image{} = image) do
    Content.image(
      data: image.data,
      mime_type: image.mime_type,
      filename: image.filename,
      width: image.width,
      height: image.height
    )
  end

  defp image_note(path, image), do: file_block(path, dimension_note(image))

  defp dimension_note(%Image{was_resized?: true} = image)
       when is_integer(image.original_width) and is_integer(image.original_height) and
              is_integer(image.width) and
              is_integer(image.height) do
    scale = image.original_width / image.width

    "[Image: original #{image.original_width}x#{image.original_height}, displayed at #{image.width}x#{image.height}. Multiply coordinates by #{Float.round(scale, 2)} to map to original image.]"
  end

  defp dimension_note(_image), do: ""

  defp file_block(path, content),
    do: "<file name=\"#{escape_xml_attr(path)}\">#{escape_xml(content)}</file>\n"

  defp escape_xml_attr(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp resolve("~" <> rest, _root), do: Path.expand("~" <> rest)
  defp resolve(path, root), do: Path.expand(path, root)

  defp empty_text?(%Content.Text{text: ""}), do: true
  defp empty_text?(_part), do: false
end
