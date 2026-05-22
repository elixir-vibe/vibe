defmodule Vibe.CLI.Output.Payload do
  @moduledoc false

  @spec build(term(), keyword()) :: {:stdio | :stderr, String.t(), :ok | {:error, term()}}
  def build(:ok, opts), do: build({:ok, %{ok: true}}, opts)

  def build({:ok, results}, opts) when is_list(results) do
    {:stdio, success_payload(:results, results, opts), :ok}
  end

  def build({:ok, result}, opts) do
    {:stdio, success_payload(:result, result, opts), :ok}
  end

  def build({:error, reason}, opts) do
    message = error_payload(reason, opts)
    device = if json?(opts), do: :stdio, else: :stderr
    {device, message, {:error, reason}}
  end

  def build(result, opts), do: build({:ok, result}, opts)

  defp success_payload(key, value, opts) do
    if json?(opts) do
      %{ok: true}
      |> Map.put(key, value)
      |> json()
    else
      Vibe.CLI.Output.Renderer.render(value)
    end
  end

  defp error_payload(reason, opts) do
    if json?(opts),
      do: json(%{ok: false, error: inspect(reason)}),
      else: "error: #{inspect(reason)}"
  end

  defp json?(opts), do: opts[:mode] == "json"
  defp json(value), do: value |> json_output_value() |> Jason.encode!(pretty: true)

  defp json_output_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_output_value(%_{} = value), do: value |> Map.from_struct() |> json_output_value()

  defp json_output_value(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, json_output_value(value)} end)

  defp json_output_value(list) when is_list(list), do: Enum.map(list, &json_output_value/1)
  defp json_output_value(value), do: value
end
