defmodule Vibe.Storage.Import do
  @moduledoc "Session import dispatcher for external sources."
  alias Vibe.Storage.Schema.Import

  @providers %{
    "pi" => Vibe.Storage.Import.Pi
  }

  @spec import_path(atom() | String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def import_path(source, path, opts \\ [])

  def import_path(source, path, opts) when is_atom(source),
    do: import_path(Atom.to_string(source), path, opts)

  def import_path(source, path, opts) when is_binary(source) do
    case Map.fetch(@providers, source) do
      {:ok, importer} ->
        import_with_opts(importer, path, opts)

      :error ->
        {:error, {:unknown_import_source, source}}
    end
  end

  defp import_with_opts(importer, path, opts) do
    Code.ensure_loaded(importer)

    if function_exported?(importer, :import_path, 2) do
      importer.import_path(path, opts)
    else
      importer.import_path(path)
    end
  end

  @spec pi_path(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def pi_path(path, opts \\ []), do: import_path("pi", path, opts)

  @spec providers() :: %{String.t() => module()}
  def providers, do: @providers

  @spec imported?(String.t()) :: boolean()
  def imported?(id) when is_binary(id) do
    Vibe.Storage.ensure!()
    not is_nil(Vibe.Repo.get(Import, id))
  end

  @spec record!(atom(), String.t(), map()) :: term()
  def record!(source, id, metadata) when is_atom(source) and is_binary(id) and is_map(metadata) do
    now = Vibe.Storage.normalize_datetime(DateTime.utc_now())
    source = Atom.to_string(source)

    %Import{id: id, source: source, imported_at: now, metadata: metadata}
    |> Vibe.Repo.insert(
      on_conflict: [set: [source: source, imported_at: now, metadata: metadata]],
      conflict_target: :id
    )
  end
end
