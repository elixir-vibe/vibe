defmodule Exy.Actions.Eval do
  @moduledoc false

  import JSONSpec

  alias Exy.Actions.Result

  @schema schema(
            %{
              required(:code) => String.t(),
              optional(:timeout) => pos_integer()
            },
            doc: [code: "Elixir code to evaluate", timeout: "Timeout in milliseconds"]
          )

  use Jido.Action,
    name: "elixir_eval",
    description:
      "Evaluate Elixir code inside Exy's BEAM runtime. Prefer this for OTP introspection, profiling, docs, and helper modules.",
    schema: @schema

  @impl true
  def run(params, _context) do
    params = JSONSpec.atomize(@schema, params)

    Result.run(fn ->
      case Exy.Eval.run(params.code, timeout: Map.get(params, :timeout, 30_000)) do
        {:ok, text} -> Result.ok(%{output: text})
        {:error, error} -> Result.error(error)
      end
    end)
  end
end
