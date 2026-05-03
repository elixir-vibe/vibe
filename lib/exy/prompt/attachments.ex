defmodule Exy.Prompt.Attachments do
  @moduledoc "Parses lightweight prompt file attachments such as `@image.png`."

  alias Exy.Image
  alias Exy.Model.Content

  @attachment_pattern ~r/(^|\s)@([^\s]+)/

  @spec expand(String.t(), keyword()) :: String.t() | [Content.t()]
  def expand(prompt, opts \\ []) when is_binary(prompt) do
    root = Keyword.get_lazy(opts, :root, &File.cwd!/0)

    case attachments(prompt, root) do
      [] ->
        prompt

      attachments ->
        text =
          Regex.replace(@attachment_pattern, prompt, fn _match, prefix, raw_path ->
            if image_attachment?(raw_path, root), do: prefix, else: "#{prefix}@#{raw_path}"
          end)

        [Content.text(String.trim(text)) | Enum.map(attachments, &image_content/1)]
        |> Enum.reject(&empty_text?/1)
    end
  end

  @spec attachments(String.t(), Path.t()) :: [Path.t()]
  def attachments(prompt, root) when is_binary(prompt) and is_binary(root) do
    @attachment_pattern
    |> Regex.scan(prompt)
    |> Enum.map(fn [_match, _prefix, raw_path] -> raw_path end)
    |> Enum.filter(&image_attachment?(&1, root))
    |> Enum.map(&resolve(&1, root))
  end

  defp image_attachment?(raw_path, root) do
    path = resolve(raw_path, root)
    File.regular?(path) and Image.supported?(path)
  end

  defp image_content(path) do
    {:ok, image} = Image.from_file(path, resize?: true)

    Content.image(
      data: image.data,
      mime_type: image.mime_type,
      filename: image.filename,
      width: image.width,
      height: image.height
    )
  end

  defp resolve("~" <> rest, _root), do: Path.expand("~" <> rest)
  defp resolve(path, root), do: Path.expand(path, root)

  defp empty_text?(%Content.Text{text: ""}), do: true
  defp empty_text?(_part), do: false
end
