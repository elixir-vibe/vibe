defmodule Vibe.Session.EvalContext do
  @moduledoc "Builds model context from user-initiated eval executions."

  @spec block([map()]) :: String.t()
  def block(messages) do
    messages
    |> Enum.filter(&included?/1)
    |> Enum.map_join("\n\n", &entry/1)
    |> case do
      "" -> ""
      entries -> "<user-evals>\n" <> entries <> "\n</user-evals>"
    end
  end

  defp included?(%{role: :eval, include_context?: true, status: status})
       when status in [:ok, :error],
       do: true

  defp included?(_message), do: false

  defp entry(%{code: code, status: :ok} = eval) do
    [
      "<eval>\n<code>\n",
      code,
      "\n</code>\n<result>\n",
      output(eval),
      "\n</result>\n</eval>"
    ]
    |> IO.iodata_to_binary()
  end

  defp entry(%{code: code, status: :error} = eval) do
    [
      "<eval>\n<code>\n",
      code,
      "\n</code>\n<error>\n",
      output(eval),
      "\n</error>\n</eval>"
    ]
    |> IO.iodata_to_binary()
  end

  defp output(%{output: output}) when is_binary(output), do: output
  defp output(%{error: error}), do: inspect(error)
  defp output(_eval), do: ""
end
