defmodule Exy.Tool.Display do
  @moduledoc "Internal implementation module."
  defstruct name: nil,
            status: nil,
            summary: nil,
            summary_style: nil,
            meta: [],
            body: [],
            expanded?: false,
            truncate?: true

  @type block ::
          {:text, String.t(), keyword()}
          | {:inspect, String.t(), keyword()}
          | {:markdown, String.t(), keyword()}
          | {:source, String.t(), keyword()}
          | {:error, String.t(), keyword()}
          | {:diff, String.t(), keyword()}
          | {:lines, [IO.chardata()], keyword()}
          | {:render, (pos_integer(), Exy.TUI.Theme.t() -> [IO.chardata()]), keyword()}

  @type t :: %__MODULE__{
          name: atom() | String.t() | nil,
          status: atom() | String.t() | nil,
          summary: IO.chardata() | nil,
          summary_style: atom() | nil,
          meta: [IO.chardata()],
          body: [block()],
          expanded?: boolean(),
          truncate?: boolean()
        }

  alias Exy.Tool.Display.{Eval, Read}
  alias Exy.TUI.ToolWidget
  alias Exy.TUI.Widgets.Tools.{AST, FileMutation, FileTool, LSP}

  @spec from_tool(map()) :: t() | {:legacy, map()}
  def from_tool(%__MODULE__{} = display), do: display

  def from_tool(%{name: name} = tool) when name in [:eval, "eval"], do: Eval.from_tool(tool)
  def from_tool(%{name: name} = tool) when name in [:read, "read"], do: Read.from_tool(tool)

  def from_tool(%{name: name} = tool) when name in [:write, "write"],
    do: file_mutation(tool, :write)

  def from_tool(%{name: name} = tool) when name in [:edit, "edit"], do: file_mutation(tool, :edit)
  def from_tool(%{name: name} = tool) when name in [:ast, "ast"], do: ast(tool)
  def from_tool(%{name: name} = tool) when name in [:lsp, "lsp"], do: lsp(tool)
  def from_tool(tool) when is_map(tool), do: generic(tool)

  defp file_mutation(tool, name) do
    result = ToolWidget.output(tool)

    %__MODULE__{
      name: name,
      status: Map.get(tool, :status),
      summary: FileTool.path_summary(tool, result),
      body: file_mutation_body(result, name),
      expanded?: expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp file_mutation_body(%{change: %{diff: diff}} = result, :edit) when is_binary(diff) do
    [{:diff, diff, language: language_from_path(Map.get(result, :path))}]
  end

  defp file_mutation_body(%{change: %{new: source}} = result, :write) when is_binary(source) do
    [{:source, source, language: language_from_path(Map.get(result, :path))}]
  end

  defp file_mutation_body(result, _name) do
    [
      {:render,
       fn width, theme ->
         FileMutation.output_lines(result, width, theme)
       end, []}
    ]
  end

  defp language_from_path(path) when is_binary(path) do
    case Path.extname(path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".heex" -> "heex"
      ".css" -> "css"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".md" -> "markdown"
      extension -> String.trim_leading(extension, ".")
    end
  end

  defp language_from_path(_path), do: "text"

  defp ast(tool) do
    result = Map.get(tool, :output) || Map.get(tool, :result) || Map.get(tool, :matches)

    %__MODULE__{
      name: :ast,
      status: Map.get(tool, :status),
      summary: AST.summary(tool, result),
      meta:
        [ast_action(tool) | AST.meta(tool, result)]
        |> Enum.reject(&(&1 in [nil, ""])),
      body: [
        {:render, fn width, theme -> AST.output_lines(result, width, theme) end, []}
      ],
      expanded?: expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp lsp(tool) do
    output = Map.get(tool, :output) || Map.get(tool, :result)

    %__MODULE__{
      name: :lsp,
      status: Map.get(tool, :status),
      summary: LSP.summary(tool, output),
      meta: LSP.meta(tool),
      body: lsp_body(output),
      expanded?: expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp ast_action(tool) do
    args = Map.get(tool, :args) || %{}

    case Map.get(args, :action) do
      nil -> nil
      action -> to_string(action)
    end
  end

  defp lsp_body(%{error: error}), do: [{:error, to_string(error), truncation: :tail}]
  defp lsp_body(_output), do: []

  defp generic(tool) do
    %__MODULE__{
      name: Map.get(tool, :name),
      status: Map.get(tool, :status),
      summary: ToolWidget.compact_summary(tool),
      body: [
        {:inspect, ToolWidget.format_value(ToolWidget.output(tool)), truncation: :tail}
      ],
      expanded?: expanded?(tool),
      truncate?: Map.get(tool, :truncate?, true)
    }
  end

  defp expanded?(tool), do: Map.get(tool, :expanded?, false) or Map.get(tool, :truncate?) == false
end
