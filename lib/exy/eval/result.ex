defmodule Exy.Eval.Result do
  @moduledoc """
  Structured eval display result.

  `format` tells renderers how to display `output` without guessing from source
  code or inspected text. Future rich outputs can add formats such as images
  while keeping the eval/tool boundary typed.
  """

  @type format :: :inspect | :text | :markdown
  @type part ::
          %{required(:output) => String.t(), required(:format) => format()}
          | Exy.Model.Content.t()

  @type t :: %__MODULE__{
          output: String.t(),
          format: format(),
          parts: [part()],
          io: String.t(),
          value_type: atom() | module()
        }

  @enforce_keys [:output, :format]
  defstruct [:output, :format, :value_type, parts: [], io: ""]

  @spec to_tool_output(t()) :: map()
  def to_tool_output(%__MODULE__{} = result) do
    %{
      output: result.output,
      output_format: result.format,
      output_parts: result.parts
    }
  end
end
