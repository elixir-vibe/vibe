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
          status: status() | nil
        }

  defstruct [:id, :name, :args, :output, :status]

  @spec started(keyword()) :: t()
  def started(fields), do: build(Keyword.put_new(fields, :status, :running))

  @spec finished(keyword()) :: t()
  def finished(fields) do
    fields
    |> Keyword.update(:output, nil, &normalize_result/1)
    |> Keyword.put_new(:status, status_from_output(Keyword.get(fields, :output)))
    |> build()
  end

  defp build(fields) do
    %__MODULE__{
      id: Keyword.get(fields, :id),
      name: Keyword.get(fields, :name),
      args: Keyword.get(fields, :args),
      output: Keyword.get(fields, :output),
      status: Keyword.get(fields, :status)
    }
  end

  defp status_from_output(output) do
    case normalize_result(output) do
      %{error: _error} -> :error
      _result -> :ok
    end
  end

  @spec normalize_result(term()) :: term()
  def normalize_result({:ok, result, _effects}), do: unwrap_output(result)
  def normalize_result({:ok, result}), do: unwrap_output(result)
  def normalize_result({:error, reason, _effects}), do: %{error: reason}
  def normalize_result({:error, reason}), do: %{error: reason}
  def normalize_result(result), do: unwrap_output(result)

  defp unwrap_output(%{output: output}) when is_binary(output), do: output
  defp unwrap_output(result), do: result
end
