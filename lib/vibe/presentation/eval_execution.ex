defmodule Vibe.Presentation.EvalExecution do
  @moduledoc "Renderer-neutral presentation for user-initiated eval executions."

  alias Vibe.Presentation.Tool.Eval

  @spec present(map() | struct()) :: Vibe.Presentation.Tool.Display.t()
  def present(eval) do
    eval = eval_map(eval)

    eval
    |> Map.put(:name, :eval)
    |> Map.put(:args, %{code: Map.get(eval, :code)})
    |> Map.update(:output, Map.get(eval, :error), fn output -> output || Map.get(eval, :error) end)
    |> Eval.from_tool()
  end

  defp eval_map(%struct{} = eval) when is_atom(struct), do: Map.from_struct(eval)
  defp eval_map(eval) when is_map(eval), do: eval
end
