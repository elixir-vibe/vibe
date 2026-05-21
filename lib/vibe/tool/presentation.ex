defmodule Vibe.Tool.Presentation do
  @moduledoc "Renderer-neutral presentation for tool lifecycle events and results."
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
          | {:image, map(), keyword()}

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

  alias Vibe.Tool.Presentation.{AST, Eval, FileMutation, Generic, LSP, Read}

  @spec from_tool(map()) :: t() | {:legacy, map()}
  def from_tool(%__MODULE__{} = display), do: display

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
