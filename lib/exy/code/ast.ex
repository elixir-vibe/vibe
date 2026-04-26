defmodule Exy.Code.AST do
  @moduledoc """
  Single ExAST gateway for structural Elixir search, replace, and diff.

  The agent should use this instead of grep for Elixir syntax. `rg` remains
  appropriate for plain text, docs, config keys, and non-Elixir assets.
  """

  @type action :: :search | :replace | :diff

  @spec run(map() | keyword()) :: {:ok, term()} | {:error, String.t()}
  def run(params) when is_map(params) or is_list(params) do
    params = normalize_params(params)

    case Map.get(params, :action) do
      :search -> search(params)
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
      {:ok, ExAST.search(path, pattern, opts)}
    end
  end

  defp replace(params) do
    with {:ok, path} <- fetch(params, :path),
         {:ok, pattern} <- fetch(params, :pattern),
         {:ok, replacement} <- fetch(params, :replacement) do
      opts = Keyword.put(where_opts(params), :dry_run, Map.get(params, :dry_run, true))
      {:ok, ExAST.replace(path, pattern, replacement, opts)}
    end
  end

  defp diff(params) do
    cond do
      Map.has_key?(params, :old_file) and Map.has_key?(params, :new_file) ->
        {:ok, ExAST.diff_files(params.old_file, params.new_file)}

      Map.has_key?(params, :old_source) and Map.has_key?(params, :new_source) ->
        {:ok, ExAST.diff(params.old_source, params.new_source)}

      true ->
        {:error, "diff requires old_file/new_file or old_source/new_source"}
    end
  end

  defp where_opts(params) do
    []
    |> maybe_put(:inside, Map.get(params, :inside))
    |> maybe_put(:not_inside, Map.get(params, :not_inside))
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp fetch(params, key), do: Exy.Params.fetch_required(params, key)

  defp normalize_params(params) do
    params
    |> Map.new(fn {key, value} -> {normalize_key(key), normalize_value(key, value)} end)
    |> Map.update(:action, nil, &normalize_action/1)
  end

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)

  defp normalize_value(key, value) when key in [:action, "action"], do: normalize_action(value)
  defp normalize_value(_key, value), do: value

  defp normalize_action(value) when is_atom(value), do: value

  defp normalize_action(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> :unknown
  end
end
