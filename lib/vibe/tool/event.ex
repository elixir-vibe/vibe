defmodule Vibe.Tool.Event do
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
          output_parts: [map()] | nil,
          output_truncation: :head | :tail | nil,
          status: status() | nil,
          phase: atom() | nil
        }

  defstruct [
    :id,
    :name,
    :args,
    :output,
    :output_format,
    :output_parts,
    :output_truncation,
    :status,
    :phase
  ]

  @spec preparing(keyword()) :: t()
  def preparing(fields),
    do:
      build(fields |> Keyword.put_new(:status, :preparing) |> Keyword.put_new(:phase, :preparing))

  @spec started(keyword()) :: t()
  def started(fields), do: build(Keyword.put_new(fields, :status, :running))

  @spec finished(keyword()) :: t()
  def finished(fields) do
    normalized = normalize_result(Keyword.get(fields, :output))

    fields
    |> Keyword.put(:output, unwrap_output(normalized))
    |> Keyword.put_new(:output_format, output_format(normalized))
    |> Keyword.put_new(:output_parts, output_parts(normalized))
    |> Keyword.put_new(:output_truncation, output_truncation(normalized))
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
      output_parts: Keyword.get(fields, :output_parts),
      output_truncation: Keyword.get(fields, :output_truncation),
      status: Keyword.get(fields, :status),
      phase: Keyword.get(fields, :phase)
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

  defp output_format(%{output_format: format}) when format in [:inspect, :text, :markdown],
    do: format

  defp output_format(_result), do: nil

  defp output_parts(%{output_parts: parts}) when is_list(parts), do: parts
  defp output_parts(_result), do: nil

  defp output_truncation(%{output_truncation: truncation}) when truncation in [:head, :tail],
    do: truncation

  defp output_truncation(_result), do: nil
end

defimpl Jason.Encoder, for: Vibe.Tool.Event do
  def encode(event, opts) do
    event
    |> Map.from_struct()
    |> Vibe.JSON.Encode.value()
    |> Jason.Encode.map(opts)
  end
end
