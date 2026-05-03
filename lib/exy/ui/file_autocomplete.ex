defmodule Exy.UI.FileAutocomplete do
  @moduledoc "File path autocomplete for prompt attachments and path-like input."

  alias Exy.UI.Autocomplete

  @max_items 20

  @spec autocomplete(String.t(), keyword()) :: Autocomplete.t() | nil
  def autocomplete(text, opts \\ []) when is_binary(text) do
    with {:ok, prefix} <- prefix(text),
         items when items != [] <- suggestions(prefix, opts) do
      Autocomplete.new(
        title: if(prefix.at?, do: "Attach file", else: "File"),
        query: prefix.raw,
        items: items,
        limit: Keyword.get(opts, :limit, 8),
        empty_message: "No files"
      )
    else
      _ -> nil
    end
  end

  @spec prefix(String.t()) :: {:ok, map()} | :error
  def prefix(text) when is_binary(text) do
    cond do
      match = Regex.run(~r/(^|\s)@"([^"]*)$/, text) ->
        {:ok, %{token: List.last(match), raw: List.last(match), at?: true, quoted?: true}}

      match = Regex.run(~r/(^|\s)@([^\s]*)$/, text) ->
        {:ok, %{token: List.last(match), raw: List.last(match), at?: true, quoted?: false}}

      match = Regex.run(~r/(^|\s)(~?\.?\.?\/?[^\s]*\/)$/, text) ->
        {:ok, %{token: List.last(match), raw: List.last(match), at?: false, quoted?: false}}

      true ->
        :error
    end
  end

  defp suggestions(prefix, opts) do
    root = Keyword.get_lazy(opts, :root, &File.cwd!/0)
    base = base_dir(prefix.raw, root)
    query = Path.basename(prefix.raw)

    base
    |> list_entries()
    |> Enum.filter(&String.starts_with?(Path.basename(&1), query))
    |> Enum.take(@max_items)
    |> Enum.map(&item(&1, prefix, root))
  end

  defp base_dir("", root), do: root
  defp base_dir(raw, root), do: raw |> Path.dirname() |> expand(root)

  defp list_entries(dir) do
    case File.ls(dir) do
      {:ok, entries} -> Enum.map(entries, &Path.join(dir, &1))
      {:error, _reason} -> []
    end
  end

  defp item(path, prefix, root) do
    directory? = File.dir?(path)
    value = completion_value(path, prefix, root, directory?)

    %{
      value: value,
      label: Path.basename(path) <> if(directory?, do: "/", else: ""),
      detail: Path.relative_to(path, root),
      group: if(prefix.at?, do: :attachment, else: :file)
    }
  end

  defp completion_value(path, prefix, root, directory?) do
    relative = path |> Path.relative_to(root) |> maybe_dir(directory?)
    quote? = prefix.quoted? or String.contains?(relative, " ")

    cond do
      prefix.at? and quote? -> ~s(@"#{relative}")
      prefix.at? -> "@#{relative}"
      quote? -> ~s("#{relative}")
      true -> relative
    end
  end

  defp maybe_dir(path, true), do: path <> "/"
  defp maybe_dir(path, false), do: path

  defp expand("~" <> rest, _root), do: Path.expand("~" <> rest)
  defp expand(path, root), do: Path.expand(path, root)
end
