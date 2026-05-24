defmodule Vibe.Session.EvalInput do
  @moduledoc "Parses user-facing bang eval input into session command data."

  @type parsed :: {:eval, String.t(), boolean()} | :prompt

  @spec parse(String.t()) :: parsed()
  def parse("!!" <> code), do: eval(code, false)
  def parse("!" <> code), do: eval(code, true)
  def parse(_text), do: :prompt

  defp eval(code, include_context?) do
    case String.trim(code) do
      "" -> :prompt
      code -> {:eval, code, include_context?}
    end
  end
end
