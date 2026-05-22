defmodule Vibe.Presentation.Tool do
  @moduledoc "Renderer-neutral presentation for tool lifecycle events and results."
  alias Vibe.Presentation.Tool.{AST, Display, Eval, FileMutation, Generic, LSP, Read}

  @spec from_tool(map()) :: Display.t() | {:legacy, map()}
  def from_tool(%Display{} = display), do: display

  def from_tool(%{name: name} = tool) when name in [:eval, "eval"], do: Eval.from_tool(tool)
  def from_tool(%{name: name} = tool) when name in [:read, "read"], do: Read.from_tool(tool)

  def from_tool(%{name: name} = tool) when name in [:write, "write"],
    do: FileMutation.from_tool(tool, :write)

  def from_tool(%{name: name} = tool) when name in [:edit, "edit"],
    do: FileMutation.from_tool(tool, :edit)

  def from_tool(%{name: name} = tool) when name in [:ast, "ast"], do: AST.from_tool(tool)
  def from_tool(%{name: name} = tool) when name in [:lsp, "lsp"], do: LSP.from_tool(tool)
  def from_tool(tool) when is_map(tool), do: Generic.from_tool(tool)
end
