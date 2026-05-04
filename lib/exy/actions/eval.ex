defmodule Exy.Actions.Eval do
  @moduledoc "Model-facing Elixir eval tool."
  import JSONSpec

  alias Exy.Actions.ToolResult

  @schema schema(
            %{
              required(:code) => String.t(),
              optional(:timeout) => pos_integer()
            },
            doc: [code: "Elixir code to evaluate", timeout: "Timeout in milliseconds"]
          )

  @default_timeout_ms 86_400_000

  use Jido.Action,
    name: "eval",
    description:
      "Evaluate Elixir code inside Exy's BEAM runtime. Prefer this for OTP introspection, profiling, docs, and helper modules.",
    schema: @schema

  @doc """
  Returns the eval action timeout ceiling used when params omit `:timeout`.
  """
  def default_timeout_ms, do: @default_timeout_ms

  @impl true
  def run(params, context) do
    params = JSONSpec.atomize(@schema, params)

    ToolResult.run(fn ->
      opts = [timeout: Map.get(params, :timeout, @default_timeout_ms)]

      params.code
      |> evaluate(session_id(context), opts)
      |> case do
        {:ok, result} -> ToolResult.ok(Exy.Eval.Result.to_tool_output(result))
        {:error, error} -> ToolResult.error(error)
      end
    end)
  end

  defp evaluate(code, session_id, opts) when is_binary(session_id),
    do: Exy.Eval.run(code, Keyword.put(opts, :session_id, session_id))

  defp evaluate(code, _session_id, opts), do: Exy.Eval.once(code, opts)

  defp session_id(context) when is_map(context), do: Map.get(context, :session_id)
  defp session_id(_context), do: nil
end
