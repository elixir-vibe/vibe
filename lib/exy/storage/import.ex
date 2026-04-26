defmodule Exy.Storage.Import do
  @moduledoc false

  alias Exy.Storage.Schema.Import

  @providers %{
    "pi" => Exy.Storage.Import.Pi
  }

  @spec import_path(atom() | String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def import_path(source, path) when is_atom(source),
    do: import_path(Atom.to_string(source), path)

  def import_path(source, path) when is_binary(source) do
    case Map.fetch(@providers, source) do
      {:ok, importer} -> importer.import_path(path)
      :error -> {:error, {:unknown_import_source, source}}
    end
  end

  @spec pi_path(String.t()) :: {:ok, map()} | {:error, term()}
  def pi_path(path), do: import_path("pi", path)

  @spec providers() :: %{String.t() => module()}
  def providers, do: @providers

  @spec record!(atom(), String.t(), map()) :: term()
  def record!(source, id, metadata) when is_atom(source) and is_binary(id) and is_map(metadata) do
    now = Exy.Storage.normalize_datetime(DateTime.utc_now())
    source = Atom.to_string(source)

    %Import{id: id, source: source, imported_at: now, metadata: metadata}
    |> Exy.Repo.insert(
      on_conflict: [set: [source: source, imported_at: now, metadata: metadata]],
      conflict_target: :id
    )
  end
end
