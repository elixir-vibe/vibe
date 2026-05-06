defmodule Exy.Code.AST do
  @moduledoc """
  Single ExAST gateway for structural Elixir search, replace, and diff.

  The agent should use this instead of grep for Elixir syntax. `rg` remains
  appropriate for plain text, docs, config keys, and non-Elixir assets.
  """

  alias Exy.Code.AST.Result

  @type action :: :search | :search_many | :replace | :diff

  @spec run(map() | keyword()) :: {:ok, term()} | {:error, String.t()}
  def run(params) when is_map(params) or is_list(params) do
    params = normalize_params(params)

    case Map.get(params, :action) do
      :search -> search(params)
      :search_many -> search_many(params)
      :replace -> replace(params)
      :diff -> diff(params)
      other -> {:error, "unknown ast action: #{inspect(other)}"}
    end
  rescue
    exception -> {:error, Exception.format(:error, exception, __STACKTRACE__)}
  end

  defp search(params) do
    with {:ok, path} <- fetch(params, :path),
         {:ok, pattern} <- fetch(params, :pattern) do
      opts = where_opts(params)

      {:ok,
       %Result{
         action: :search,
         path: path,
         pattern: pattern,
         result: ExAST.search(path, pattern, opts)
       }}
    end
  end

  @doc """
  Searches for multiple named ExAST patterns in one traversal.

  This is a compact public helper for checks/analyzers that need to scan the
  same files for several structural patterns without repeatedly reparsing and
  walking the tree.
  """
  @spec search_many(Path.t() | [Path.t()], map() | keyword(), keyword()) :: [map()]
  def search_many(path, patterns, opts \\ []) do
    ExAST.search_many(path, patterns, opts)
  end

  defp search_many(params) do
    with {:ok, path} <- fetch(params, :path),
         {:ok, patterns} <- fetch(params, :patterns) do
      opts = where_opts(params) |> maybe_put(:limit, Map.get(params, :limit))

      {:ok,
       %Result{
         action: :search_many,
         path: path,
         pattern: patterns,
         result: search_many(path, patterns, opts)
       }}
    end
  end

  defp replace(params) do
    with {:ok, path} <- fetch(params, :path),
         {:ok, pattern} <- fetch(params, :pattern),
         {:ok, replacement} <- fetch(params, :replacement) do
      dry_run = Map.get(params, :dry_run, true)
      opts = Keyword.put(where_opts(params), :dry_run, dry_run)
      diff = replacement_diff(path, pattern, replacement, where_opts(params))

      {:ok,
       %Result{
         action: :replace,
         path: path,
         pattern: pattern,
         replacement: replacement,
         dry_run: dry_run,
         result: ExAST.replace(path, pattern, replacement, opts),
         diff: diff
       }}
    end
  end

  defp diff(params) do
    cond do
      Map.has_key?(params, :old_file) and Map.has_key?(params, :new_file) ->
        {:ok,
         %Result{
           action: :diff,
           path: params.old_file,
           replacement: params.new_file,
           result: ExAST.diff_files(params.old_file, params.new_file)
         }}

      Map.has_key?(params, :old_source) and Map.has_key?(params, :new_source) ->
        {:ok,
         %Result{
           action: :diff,
           result: ExAST.diff(params.old_source, params.new_source)
         }}

      true ->
        {:error, "diff requires old_file/new_file or old_source/new_source"}
    end
  end

  defp replacement_diff(path, pattern, replacement, where_opts) do
    path
    |> resolve_paths()
    |> Enum.flat_map(fn file ->
      source = File.read!(file)
      replaced = ExAST.Patcher.replace_all(source, pattern, replacement, where_opts)

      if source == replaced do
        []
      else
        [%{path: file, diff: Exy.Code.AST.TextDiff.unified(source, replaced, file)}]
      end
    end)
  end

  defp where_opts(params) do
    []
    |> maybe_put(:inside, Map.get(params, :inside))
    |> maybe_put(:not_inside, Map.get(params, :not_inside))
    |> maybe_put(:allow_broad, Map.get(params, :allow_broad))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp fetch(params, key), do: Exy.Params.fetch_required(params, key)

  defp resolve_paths(paths) when is_list(paths), do: Enum.flat_map(paths, &resolve_paths/1)

  defp resolve_paths(glob) when is_binary(glob) do
    cond do
      String.contains?(glob, "*") -> Path.wildcard(glob)
      File.dir?(glob) -> Path.wildcard(Path.join(glob, "**/*.ex"))
      true -> [glob]
    end
    |> Enum.filter(&String.ends_with?(&1, ".ex"))
  end

  defp normalize_params(params) do
    params
    |> Map.new(fn {key, value} -> {normalize_key(key), normalize_value(key, value)} end)
    |> Map.update(:action, nil, &normalize_action/1)
  end

  defp normalize_key(key) when is_atom(key), do: key

  defp normalize_key(key) when is_binary(key) do
    case key do
      "action" -> :action
      "path" -> :path
      "pattern" -> :pattern
      "patterns" -> :patterns
      "replacement" -> :replacement
      "old_file" -> :old_file
      "new_file" -> :new_file
      "old_source" -> :old_source
      "new_source" -> :new_source
      "inside" -> :inside
      "not_inside" -> :not_inside
      "dry_run" -> :dry_run
      "allow_broad" -> :allow_broad
      "limit" -> :limit
      _unknown -> key
    end
  end

  defp normalize_value(key, value) when key in [:action, "action"], do: normalize_action(value)
  defp normalize_value(_key, value), do: value

  defp normalize_action("search_many"), do: :search_many
  defp normalize_action(value) when is_atom(value), do: value

  defp normalize_action(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :unknown
  end
end
