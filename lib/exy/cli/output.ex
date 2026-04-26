defmodule Exy.CLI.Output do
  @moduledoc false

  @spec print(term(), keyword()) :: :ok | {:error, term()}
  def print(:ok, opts), do: print({:ok, %{ok: true}}, opts)

  def print({:ok, results}, opts) when is_list(results) do
    case opts[:mode] do
      "json" -> IO.puts(Jason.encode!(json_safe(%{ok: true, results: results}), pretty: true))
      _ -> IO.puts(render(results))
    end

    :ok
  end

  def print({:ok, result}, opts) do
    case opts[:mode] do
      "json" -> IO.puts(Jason.encode!(json_safe(%{ok: true, result: result}), pretty: true))
      _ -> IO.puts(render(result))
    end

    :ok
  end

  def print({:error, reason}, opts) do
    case opts[:mode] do
      "json" ->
        IO.puts(Jason.encode!(json_safe(%{ok: false, error: inspect(reason)}), pretty: true))

      _ ->
        error(inspect(reason))
    end

    {:error, reason}
  end

  @spec error(String.t()) :: :ok
  def error(message) do
    IO.puts(:stderr, "error: #{message}")
  end

  defp json_safe(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp json_safe(%_{} = value), do: value |> Map.from_struct() |> json_safe()

  defp json_safe(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {key, json_safe(value)} end)

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(value), do: value

  defp render([]), do: "No results."
  defp render([%{id: _id} | _rest] = sessions), do: render_sessions(sessions)

  defp render(results) when is_list(results),
    do: Enum.map_join(results, "\n", &inspect(&1, pretty: true, limit: 20))

  defp render(%ReqLLM.Response{} = response),
    do: response |> ReqLLM.Response.text() |> render_markdown()

  defp render(%{summary: summary}), do: render_markdown(summary)
  defp render(%{output: output}), do: output
  defp render(result) when is_binary(result), do: render_markdown(result)
  defp render(result), do: inspect(result, pretty: true, limit: 50)

  defp render_sessions(sessions) do
    header = "UPDATED              LIVE STATUS  ID                         PREVIEW"

    rows =
      Enum.map(sessions, fn session ->
        updated = session[:updated_at] |> format_updated_at() |> String.pad_trailing(19)
        live = if session[:live?], do: "yes ", else: "no  "
        status = session[:status] |> to_string() |> String.pad_trailing(7)
        id = session[:id] |> to_string() |> String.slice(0, 26) |> String.pad_trailing(26)
        preview = session[:last_message_preview] || session[:first_message] || ""
        "#{updated}  #{live} #{status} #{id} #{preview}"
      end)

    Enum.join([header | rows], "\n")
  end

  defp format_updated_at(%DateTime{} = updated_at),
    do: Calendar.strftime(updated_at, "%Y-%m-%d %H:%M")

  defp format_updated_at(updated_at) when is_binary(updated_at),
    do: String.slice(updated_at, 0, 16)

  defp format_updated_at(_updated_at), do: "-"

  defp render_markdown(nil), do: ""

  defp render_markdown(text) do
    text
    |> Exy.TUI.Markdown.render(terminal_width(), Exy.TUI.Theme.default())
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
  end

  defp terminal_width do
    case :io.columns() do
      {:ok, columns} -> columns
      _ -> 100
    end
  end
end
