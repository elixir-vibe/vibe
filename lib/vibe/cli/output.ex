defmodule Vibe.CLI.Output do
  @moduledoc "CLI output formatting: ok/error results, tables, JSON."
  @spec print(term(), keyword()) :: :ok | {:error, term()}
  def print(:ok, opts), do: print({:ok, %{ok: true}}, opts)

  def print({:ok, results}, opts) when is_list(results) do
    case opts[:mode] do
      "json" ->
        puts(Jason.encode!(json_output_value(%{ok: true, results: results}), pretty: true))

      _ ->
        puts(Vibe.CLI.Output.Renderer.render(results))
    end

    :ok
  end

  def print({:ok, result}, opts) do
    case opts[:mode] do
      "json" -> puts(Jason.encode!(json_output_value(%{ok: true, result: result}), pretty: true))
      _ -> puts(Vibe.CLI.Output.Renderer.render(result))
    end

    :ok
  end

  def print({:error, reason}, opts) do
    case opts[:mode] do
      "json" ->
        puts(Jason.encode!(json_output_value(%{ok: false, error: inspect(reason)}), pretty: true))

      _ ->
        error(inspect(reason))
    end

    {:error, reason}
  end

  def print(result, opts), do: print({:ok, result}, opts)

  @spec error(String.t()) :: :ok
  def error(message) do
    puts(:stderr, "error: #{message}")
  end

  defp puts(message), do: puts(:stdio, message)

  defp puts(device, message) do
    IO.puts(device, message)
  rescue
    ErlangError -> :ok
  catch
    :exit, _reason -> :ok
  end

  defp json_output_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_output_value(%_{} = value), do: value |> Map.from_struct() |> json_output_value()

  defp json_output_value(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, json_output_value(value)} end)

  defp json_output_value(list) when is_list(list), do: Enum.map(list, &json_output_value/1)
  defp json_output_value(value), do: value
end
