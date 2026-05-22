defmodule Vibe.Tool.Builtin.Write do
  @moduledoc "Model-facing file write tool."
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
    Vibe.Tool.AdapterResult.run(fn ->
      params = JSONSpec.atomize(@schema, params)

      params.path
      |> Vibe.Files.write_file(params.content)
      |> transport_result()
    end)
  end

  defp transport_result({:ok, result}), do: {:ok, Vibe.Tool.Transport.Result.from_result(result)}
  defp transport_result(other), do: other
end
