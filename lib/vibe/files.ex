defmodule Vibe.Files do
  @moduledoc "File read, write, and edit operations for agent tools."

  alias Vibe.Files.{Artifacts, ImageRef, ReadResult}
  alias Vibe.Image
  alias Vibe.Model.Content
  @read_limit_lines 2_000

  @type edit :: %{old_text: String.t(), new_text: String.t()}

  @spec read_file(String.t(), keyword()) :: {:ok, ReadResult.t()} | {:error, String.t()}
  def read_file(path, opts \\ []) when is_binary(path) do
    with {:ok, absolute} <- Vibe.Workspace.resolve(path, opts),
         {:ok, stat} <- File.stat(absolute),
         :ok <- ensure_regular(stat),
         {:ok, content} <- File.read(absolute) do
      if Image.supported?(absolute) do
        image_result(path, absolute, content, stat, opts)
      else
        limit =
          Vibe.ToolOutput.limit_content(content,
            limit_lines: Keyword.get(opts, :limit_lines, @read_limit_lines),
            limit_bytes: Keyword.get(opts, :limit_bytes, Vibe.ToolOutput.default_max_bytes())
          )

        {:ok,
         %ReadResult{
           path: path,
           content_type: :text,
           content: limit.content,
           language: language(path),
           lines: line_count(content),
           omitted_lines: limit.omitted_lines,
           omitted_bytes: limit.omitted_bytes
         }}
      end
    end
  end

  @spec write_file(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def write_file(path, content, opts \\ []) when is_binary(path) and is_binary(content) do
    with {:ok, absolute} <- Vibe.Workspace.resolve(path, opts),
         :ok <- File.mkdir_p(Path.dirname(absolute)) do
      old = if File.exists?(absolute), do: File.read!(absolute), else: ""
      File.write!(absolute, content)
      change = change(path, old, content)

      {:ok,
       %{
         path: path,
         message: write_message(path, old),
         change: change,
         first_changed_line: first_changed_line(change.diff)
       }}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  @spec edit_file(String.t(), [edit() | map()], keyword()) :: {:ok, map()} | {:error, String.t()}
  def edit_file(path, edits, opts \\ []) when is_binary(path) and is_list(edits) do
    with {:ok, absolute} <- Vibe.Workspace.resolve(path, opts),
         {:ok, original} <- File.read(absolute),
         {:ok, edited, count} <- apply_edits(path, original, edits) do
      File.write!(absolute, edited)
      change = change(path, original, edited)

      {:ok,
       %{
         path: path,
         message: "Successfully replaced #{count} block(s) in #{path}.",
         change: change,
         replacements: count,
         first_changed_line: first_changed_line(change.diff)
       }}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp image_result(path, absolute, content, stat, opts) do
    mime_type = Image.mime_type(absolute)
    {width, height} = Image.dimensions(content, mime_type)

    image = %Image{
      data: Base.encode64(content),
      mime_type: mime_type,
      path: path,
      filename: Path.basename(path),
      size_bytes: stat.size,
      width: width,
      height: height,
      original_width: width,
      original_height: height,
      was_resized?: false
    }

    with {:ok, image} <- maybe_resize_image(image, opts),
         {:ok, stored} <- Artifacts.maybe_store_image(image, opts) do
      parts = image_parts(stored)

      {:ok,
       %ReadResult{
         path: path,
         content_type: :image,
         mime_type: stored.mime_type,
         size_bytes: stored.size_bytes,
         width: stored.width,
         height: stored.height,
         parts: parts,
         image: stored,
         __content_parts__: Content.to_req_llm_tool_parts(parts)
       }}
    end
  end

  defp maybe_resize_image(image, opts) do
    if Keyword.get(opts, :resize?, false),
      do: Vibe.Image.Resize.resize(image, opts),
      else: {:ok, image}
  end

  defp image_parts(%Image{} = image), do: Image.to_content_parts(image)

  defp image_parts(%ImageRef{} = ref) do
    note =
      [
        "Read image file [#{ref.mime_type}]",
        image_dimensions(ref),
        "Stored artifact: #{ref.path}"
      ]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join("\n")

    [
      Content.text(note),
      Content.image(
        data: ref.data,
        mime_type: ref.mime_type,
        filename: ref.filename,
        width: ref.width,
        height: ref.height
      )
    ]
  end

  defp image_dimensions(%{width: width, height: height})
       when is_integer(width) and is_integer(height),
       do: "#{width}x#{height}"

  defp image_dimensions(_image), do: nil

  defp change(path, old, new), do: %{path: path, old: old, new: new, diff: diff(old, new)}

  @spec diff(String.t(), String.t()) :: String.t()
  def diff(old, new) when is_binary(old) and is_binary(new) do
    old_lines = split_lines(old)
    new_lines = split_lines(new)
    width = max(length(old_lines), length(new_lines)) |> Integer.digits() |> length()

    old_lines
    |> List.myers_difference(new_lines)
    |> diff_groups(width, 1, 1, [])
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp ensure_regular(%File.Stat{type: :regular}), do: :ok
  defp ensure_regular(%File.Stat{type: type}), do: {:error, "not a regular file: #{type}"}

  defp apply_edits(_path, content, []), do: {:ok, content, 0}

  defp apply_edits(path, content, edits) do
    normalized = Enum.map(edits, &normalize_edit/1)

    with :ok <- validate_edits(path, content, normalized) do
      edited =
        normalized
        |> matches(content)
        |> Enum.sort_by(& &1.index, :desc)
        |> Enum.reduce(content, fn match, acc ->
          prefix = binary_part(acc, 0, match.index)
          suffix_start = match.index + byte_size(match.old_text)
          suffix = binary_part(acc, suffix_start, byte_size(acc) - suffix_start)
          IO.iodata_to_binary([prefix, match.new_text, suffix])
        end)

      if edited == content do
        {:error, "No changes made to #{path}. The replacements produced identical content."}
      else
        {:ok, edited, length(normalized)}
      end
    end
  end

  defp normalize_edit(%{old_text: old, new_text: new}), do: %{old_text: old, new_text: new}
  defp normalize_edit(%{oldText: old, newText: new}), do: %{old_text: old, new_text: new}

  defp normalize_edit(%{"old_text" => old, "new_text" => new}),
    do: %{old_text: old, new_text: new}

  defp normalize_edit(%{"oldText" => old, "newText" => new}), do: %{old_text: old, new_text: new}

  defp validate_edits(path, content, edits) do
    edits
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {edit, index}, :ok ->
      cond do
        edit.old_text == "" ->
          {:halt, {:error, "edits[#{index}].oldText must not be empty in #{path}."}}

        occurrences(content, edit.old_text) == 0 ->
          {:halt,
           {:error,
            "Could not find edits[#{index}] in #{path}. The oldText must match exactly including all whitespace and newlines."}}

        occurrences(content, edit.old_text) > 1 ->
          {:halt,
           {:error,
            "Found #{occurrences(content, edit.old_text)} occurrences of edits[#{index}] in #{path}. Each oldText must be unique. Please provide more context to make it unique."}}

        true ->
          {:cont, :ok}
      end
    end)
    |> then(fn
      :ok -> validate_non_overlapping(path, content, edits)
      error -> error
    end)
  end

  defp validate_non_overlapping(path, content, edits) do
    content
    |> matches(edits)
    |> Enum.sort_by(& &1.index)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.find(fn [left, right] -> left.index + byte_size(left.old_text) > right.index end)
    |> case do
      nil ->
        :ok

      [left, right] ->
        {:error,
         "edits[#{left.edit_index}] and edits[#{right.edit_index}] overlap in #{path}. Merge them into one edit or target disjoint regions."}
    end
  end

  defp matches(edits, content) when is_list(edits), do: matches(content, edits)

  defp matches(content, edits) do
    edits
    |> Enum.with_index()
    |> Enum.map(fn {edit, index} ->
      %{
        index: :binary.match(content, edit.old_text) |> elem(0),
        old_text: edit.old_text,
        new_text: edit.new_text,
        edit_index: index
      }
    end)
  end

  defp occurrences(content, text), do: content |> :binary.matches(text) |> length()

  defp split_lines(""), do: []

  defp split_lines(text) do
    lines = String.split(text, "\n", trim: false)
    if String.ends_with?(text, "\n"), do: Enum.drop(lines, -1), else: lines
  end

  defp diff_groups([], _width, _old_line, _new_line, acc), do: acc

  defp diff_groups([{:eq, lines} | rest], width, old_line, new_line, acc) do
    {shown, omitted, old_line, new_line} = context_lines(lines, old_line, new_line, width)
    acc = prepend_context(shown, omitted, acc)
    diff_groups(rest, width, old_line, new_line, acc)
  end

  defp diff_groups([{:del, lines} | rest], width, old_line, new_line, acc) do
    rendered =
      Enum.with_index(lines, old_line)
      |> Enum.map(fn {line, number} -> "-#{pad(number, width)}  #{line}" end)

    diff_groups(rest, width, old_line + length(lines), new_line, Enum.reverse(rendered, acc))
  end

  defp diff_groups([{:ins, lines} | rest], width, old_line, new_line, acc) do
    rendered =
      Enum.with_index(lines, new_line)
      |> Enum.map(fn {line, number} -> "+#{pad(number, width)}  #{line}" end)

    diff_groups(rest, width, old_line, new_line + length(lines), Enum.reverse(rendered, acc))
  end

  defp context_lines(lines, old_line, new_line, width) do
    rendered =
      Enum.with_index(lines, old_line)
      |> Enum.map(fn {line, number} -> " #{pad(number, width)}  #{line}" end)

    {rendered, 0, old_line + length(lines), new_line + length(lines)}
  end

  defp prepend_context(lines, _omitted, acc), do: Enum.reverse(lines, acc)
  defp pad(number, width), do: number |> Integer.to_string() |> String.pad_leading(width)

  defp first_changed_line(""), do: nil

  defp first_changed_line(diff) do
    diff
    |> String.split("\n")
    |> Enum.find_value(fn
      "+" <> rest ->
        rest
        |> String.trim_leading()
        |> String.split(" ", parts: 2)
        |> hd()
        |> Integer.parse()
        |> case do
          {n, _} -> n
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  defp write_message(path, ""), do: "Created #{path}."
  defp write_message(path, _old), do: "Wrote #{path}."

  defp line_count(content), do: content |> split_lines() |> length()

  @spec language(Path.t()) :: String.t()
  def language(path) do
    case Path.extname(path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".tsx" -> "tsx"
      ".json" -> "json"
      ".md" -> "markdown"
      ext -> String.trim_leading(ext, ".")
    end
  end
end
