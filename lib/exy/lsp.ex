defmodule Exy.LSP do
  @moduledoc """
  Single Expert LSP gateway.

  Actions: `:diagnostics`, `:definition`, `:references`, `:hover`,
  `:symbols`, `:workspace_symbols`, `:code_actions`.
  """

  alias Exy.LSP.Client

  @spec run(map() | keyword()) :: {:ok, term()} | {:error, String.t() | map()}
  def run(params) when is_map(params) or is_list(params) do
    params = Map.new(params, fn {key, value} -> {normalize_key(key), value} end)
    cwd = Map.get(params, :cwd, File.cwd!())

    with {:ok, pid} <- Client.ensure_started(cwd) do
      dispatch(pid, params)
    end
  end

  defp dispatch(pid, %{action: action} = params) when action in [:diagnostics, "diagnostics"] do
    with {:ok, file} <- fetch(params, :file) do
      open_file(pid, file)
      Process.sleep(Map.get(params, :wait_ms, 500))
      {:ok, Client.diagnostics(pid, file)}
    end
  end

  defp dispatch(pid, %{action: action} = params) when action in [:definition, "definition"] do
    position_request(pid, "textDocument/definition", params)
  end

  defp dispatch(pid, %{action: action} = params) when action in [:references, "references"] do
    position_request(
      pid,
      "textDocument/references",
      Map.put(params, :context, %{includeDeclaration: Map.get(params, :include_declaration, true)})
    )
  end

  defp dispatch(pid, %{action: action} = params) when action in [:hover, "hover"] do
    position_request(pid, "textDocument/hover", params)
  end

  defp dispatch(pid, %{action: action} = params) when action in [:symbols, "symbols"] do
    with {:ok, file} <- fetch(params, :file) do
      Client.request(pid, "textDocument/documentSymbol", text_document_params(file))
    end
  end

  defp dispatch(pid, %{action: action} = params)
       when action in [:workspace_symbols, "workspace_symbols"] do
    Client.request(pid, "workspace/symbol", %{query: Map.get(params, :query, "")})
  end

  defp dispatch(pid, %{action: action} = params) when action in [:code_actions, "code_actions"] do
    with {:ok, file} <- fetch(params, :file),
         {:ok, line} <- fetch(params, :line),
         {:ok, column} <- fetch(params, :column) do
      range = %{
        start: position(line, column),
        end: position(Map.get(params, :end_line, line), Map.get(params, :end_column, column))
      }

      Client.request(
        pid,
        "textDocument/codeAction",
        Map.merge(text_document_params(file), %{range: range, context: %{diagnostics: []}})
      )
    end
  end

  defp dispatch(_pid, %{action: action}), do: {:error, "unknown LSP action: #{inspect(action)}"}
  defp dispatch(_pid, _params), do: {:error, "missing required parameter: action"}

  defp position_request(pid, method, params) do
    with {:ok, file} <- fetch(params, :file),
         {:ok, line} <- fetch(params, :line),
         {:ok, column} <- fetch(params, :column) do
      open_file(pid, file)
      Process.sleep(Map.get(params, :open_wait_ms, 200))
      extra = Map.take(params, [:context])

      Client.request(
        pid,
        method,
        Map.merge(
          Map.merge(text_document_params(file), %{position: position(line, column)}),
          extra
        )
      )
    end
  end

  defp open_file(pid, file) do
    path = Path.expand(file)
    text = File.read!(path)

    Client.notify(pid, "textDocument/didOpen", %{
      textDocument: %{uri: Client.path_uri(path), languageId: "elixir", version: 1, text: text}
    })
  end

  defp text_document(file), do: %{uri: file |> Path.expand() |> Client.path_uri()}

  defp text_document_params(file),
    do: %{textDocument: text_document(file), text_document: text_document(file)}

  defp position(line, column), do: %{line: max(line - 1, 0), character: max(column - 1, 0)}

  defp fetch(params, key), do: Exy.Params.fetch_required(params, key)

  defp normalize_key(key) when is_atom(key), do: key
  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
end
