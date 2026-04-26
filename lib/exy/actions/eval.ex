defmodule Exy.Actions.Eval do
  @moduledoc false

  import JSONSpec

  alias Exy.Actions.ToolResult

  @schema schema(
            %{
              required(:code) => String.t(),
              optional(:timeout) => pos_integer()
            },
            doc: [code: "Elixir code to evaluate", timeout: "Timeout in milliseconds"]
          )

  use Jido.Action,
    name: "eval",
    description:
      "Evaluate Elixir code inside Exy's BEAM runtime. Prefer this for OTP introspection, profiling, docs, and helper modules.",
    schema: @schema

  @impl true
  def run(params, context) do
    params = JSONSpec.atomize(@schema, params)

    ToolResult.run(fn ->
      case Exy.Eval.run(params.code,
             timeout: Map.get(params, :timeout, 30_000),
             session_id: session_id(context)
           ) do
        {:ok, text} -> ToolResult.ok(%{output: text})
        {:error, error} -> ToolResult.error(error)
      end
    end)
  end

  defp session_id(context) when is_map(context), do: Map.get(context, :session_id)
  defp session_id(_context), do: nil
end
