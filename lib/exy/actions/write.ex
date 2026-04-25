defmodule Exy.Actions.Write do
  @moduledoc false

  import JSONSpec

  @schema schema(
            %{
              required(:path) => String.t(),
              required(:content) => String.t()
            },
            doc: [path: "Path to write", content: "Full file content"]
          )

  use Jido.Action,
    name: "write",
    description: "Create or overwrite a text file. Returns a line-numbered diff of the write.",
    schema: @schema

  @impl true
  def run(params, _context) do
    params = JSONSpec.atomize(@schema, params)

    case Exy.FileTools.write_file(params.path, params.content) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:ok, %{error: error}}
    end
  end
end
