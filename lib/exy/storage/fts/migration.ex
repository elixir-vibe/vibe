defmodule Exy.Storage.FTS.Migration do
  @moduledoc "FTS5 virtual table DDL helpers for migrations."
  import Ecto.Migration

  @spec create_fts5(atom(), keyword()) :: :ok
  def create_fts5(table, opts) when is_atom(table) and is_list(opts) do
    columns = columns(opts)
    tokenizer = tokenizer(Keyword.get(opts, :tokenize, "unicode61"))

    execute("""
    CREATE VIRTUAL TABLE IF NOT EXISTS #{identifier(table)} USING fts5(
      #{Enum.join(columns, ",\n  ")},
      tokenize = '#{tokenizer}'
    )
    """)
  end

  @spec drop_fts5(atom()) :: :ok
  def drop_fts5(table) when is_atom(table) do
    execute("DROP TABLE IF EXISTS #{identifier(table)}")
  end

  defp columns(opts) do
    unindexed = Keyword.get(opts, :unindexed, [])
    indexed = Keyword.get(opts, :indexed, [])

    Enum.map(unindexed, &(identifier(&1) <> " UNINDEXED")) ++ Enum.map(indexed, &identifier/1)
  end

  defp identifier(value) when is_atom(value), do: value |> Atom.to_string() |> identifier()

  defp identifier(value) when is_binary(value) do
    if Regex.match?(~r/\A[a-zA-Z_][a-zA-Z0-9_]*\z/, value) do
      ~s("#{value}")
    else
      raise ArgumentError, "invalid SQLite identifier: #{inspect(value)}"
    end
  end

  defp tokenizer(value) when value in ["unicode61", "porter", "ascii", "trigram"], do: value

  defp tokenizer(value), do: raise(ArgumentError, "unsupported FTS tokenizer: #{inspect(value)}")
end
