defmodule Exy.UI.ToolEvent do
  @moduledoc """
  Structured UI event payload for tool lifecycle updates.
  """

  @type status :: :running | :ok | :error | atom() | String.t()

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: atom() | String.t() | nil,
          args: term(),
          output: term(),
          output_format: atom() | nil,
          status: status() | nil
        }

  defstruct [:id, :name, :args, :output, :output_format, :status]

  @spec started(keyword()) :: t()
  def started(fields), do: build(Keyword.put_new(fields, :status, :running))

  @spec finished(keyword()) :: t()
  def finished(fields) do
    normalized = normalize_result(Keyword.get(fields, :output))

    fields
    |> Keyword.put(:output, unwrap_output(normalized))
    |> Keyword.put_new(:output_format, output_format(normalized))
    |> Keyword.put_new(:status, status_from_output(normalized))
    |> build()
  end

  defp build(fields) do
    %__MODULE__{
      id: Keyword.get(fields, :id),
      name: Keyword.get(fields, :name),
      args: Keyword.get(fields, :args),
      output: Keyword.get(fields, :output),
      output_format: Keyword.get(fields, :output_format),
      status: Keyword.get(fields, :status)
    }
  end

  defp status_from_output(%{error: _error}), do: :error
  defp status_from_output(_output), do: :ok

  @spec normalize_result(term()) :: term()
  def normalize_result({:ok, result, _effects}), do: result
  def normalize_result({:ok, result}), do: result
  def normalize_result({:error, reason, _effects}), do: %{error: reason}
  def normalize_result({:error, reason}), do: %{error: reason}
  def normalize_result(result), do: result

  defp unwrap_output(%{output: output}), do: output
  defp unwrap_output(result), do: result

  defp output_format(%{output_format: format}) when is_atom(format), do: format
  defp output_format(_result), do: nil
end
