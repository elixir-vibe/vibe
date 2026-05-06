defmodule Vibe.Context.Recall do
  @moduledoc "Retrieves relevant context from storage and memory for prompts."
  alias Vibe.Storage.Search.Result

  @default_limit 3
  @max_text_bytes 1_200

  @spec search(String.t(), keyword()) :: {:ok, [Result.t()]} | {:error, term()}
  def search(query, opts \\ []) when is_binary(query) do
    Vibe.Storage.Search.query(query,
      cwd: Keyword.get(opts, :cwd),
      session_id: Keyword.get(opts, :session_id),
      exclude_session_id: Keyword.get(opts, :exclude_session_id),
      roles: Keyword.get(opts, :roles, [:user, :assistant]),
      scopes: Keyword.get(opts, :scopes, [:sessions, :memory]),
      limit: Keyword.get(opts, :limit, @default_limit)
    )
  end

  @spec block(String.t(), keyword()) :: String.t()
  def block(query, opts \\ []) when is_binary(query) do
    case search(query, opts) do
      {:ok, []} -> ""
      {:ok, results} -> format_block(results)
      {:error, _reason} -> ""
    end
  end

  defp format_block(results) do
    body =
      results
      |> Enum.with_index(1)
      |> Enum.map_join("\n\n", fn {result, index} -> format_result(index, result) end)

    "<recalled-history>\n" <> body <> "\n</recalled-history>"
  end

  defp format_result(index, %Result{} = result) do
    [
      Integer.to_string(index),
      ". ",
      source_label(result),
      "\n",
      result.text |> clean_text() |> truncate_text()
    ]
    |> IO.iodata_to_binary()
  end

  defp source_label(%Result{source: :session, owner_id: session_id, metadata: metadata}) do
    role = Map.get(metadata, :role, "message")
    cwd = metadata |> Map.get(:cwd) |> cwd_label()
    seq = Map.get(metadata, :seq)

    [
      "session ",
      cwd,
      " ",
      session_id || "unknown",
      " #",
      to_string(seq || "?"),
      " ",
      to_string(role)
    ]
  end

  defp source_label(%Result{source: :memory, owner_id: owner_id}),
    do: ["memory ", owner_id || "unknown"]

  defp cwd_label(nil), do: "unknown"
  defp cwd_label(cwd), do: Path.basename(cwd)

  defp clean_text(text) do
    text
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp truncate_text(text) do
    if byte_size(text) <= @max_text_bytes do
      text
    else
      text
      |> String.slice(0, @max_text_bytes)
      |> Kernel.<>("...")
    end
  end
end
