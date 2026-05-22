defmodule Vibe.CLI.Output do
  @moduledoc "CLI output formatting: ok/error results, tables, JSON."
  alias IO.ANSI
  alias ReqLLM.Response
  alias Vibe.Eval.Result, as: EvalResult
  alias Vibe.Storage.Search
  alias Vibe.Subagents.{JobInfo, Schedule}

  @spec print(term(), keyword()) :: :ok | {:error, term()}
  def print(:ok, opts), do: print({:ok, %{ok: true}}, opts)

  def print({:ok, results}, opts) when is_list(results) do
    case opts[:mode] do
      "json" ->
        puts(Jason.encode!(json_output_value(%{ok: true, results: results}), pretty: true))

      _ ->
        puts(render(results))
    end

    :ok
  end

  def print({:ok, result}, opts) do
    case opts[:mode] do
      "json" -> puts(Jason.encode!(json_output_value(%{ok: true, result: result}), pretty: true))
      _ -> puts(render(result))
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

  defp render([]), do: "No results."

  defp render([%Search.Result{} | _rest] = results),
    do: render_search_results(results)

  defp render([%JobInfo{} | _rest] = jobs), do: render_jobs(jobs)
  defp render([%Schedule{} | _rest] = schedules), do: render_schedules(schedules)
  defp render([%{id: _id} | _rest] = sessions), do: render_sessions(sessions)

  defp render(results) when is_list(results),
    do: Enum.map_join(results, "\n", &inspect(&1, pretty: true, limit: 20))

  defp render(%Response{} = response), do: response |> Response.text() |> render_markdown()

  defp render(%EvalResult{format: :markdown, output: output}), do: render_markdown(output)
  defp render(%EvalResult{output: output}), do: output
  defp render(%{summary: summary}), do: render_markdown(summary)
  defp render(%{output: output}), do: output
  defp render(result) when is_binary(result), do: render_markdown(result)
  defp render(result), do: inspect(result, pretty: true, limit: 50)

  defp render_search_results(results) do
    results
    |> Enum.with_index(1)
    |> Enum.map_join("\n\n", fn {result, index} ->
      [
        Integer.to_string(index),
        ". ",
        to_string(result.source),
        " ",
        search_result_location(result),
        " #",
        to_string(result.metadata[:seq] || result.id),
        "\n",
        highlight_search_snippet(result.snippet || result.text)
      ]
      |> IO.iodata_to_binary()
    end)
  end

  defp search_result_location(result) do
    cwd = result.metadata[:cwd]

    cond do
      is_binary(cwd) and cwd != "" -> Path.basename(cwd) <> " " <> result.owner_id
      result.owner_id -> result.owner_id
      true -> "-"
    end
  end

  defp highlight_search_snippet(text) do
    text
    |> String.replace("…", "...")
    |> String.replace("<mark>", ANSI.yellow() <> ANSI.bright())
    |> String.replace("</mark>", ANSI.reset())
  end

  defp render_jobs(jobs) do
    header = "STATUS   ID          ROLE        CHILD SESSION              TASK"

    rows =
      Enum.map(jobs, fn job ->
        status = job.status |> to_string() |> String.pad_trailing(8)
        id = job.id |> to_string() |> String.slice(0, 10) |> String.pad_trailing(10)
        role = (job.role || "-") |> to_string() |> String.slice(0, 10) |> String.pad_trailing(10)

        child =
          job.child_session_id |> to_string() |> String.slice(0, 26) |> String.pad_trailing(26)

        "#{status} #{id} #{role} #{child} #{job.task}"
      end)

    Enum.join([header | rows], "\n")
  end

  defp render_schedules(schedules) do
    header = "ID          NEXT RUN             EVERY_MS  TASK"

    rows =
      Enum.map(schedules, fn schedule ->
        id = schedule.id |> to_string() |> String.slice(0, 10) |> String.pad_trailing(10)
        next_run = schedule.next_run_at |> format_updated_at() |> String.pad_trailing(19)
        every = (schedule.every_ms || "-") |> to_string() |> String.pad_trailing(8)
        "#{id} #{next_run} #{every}  #{schedule.task}"
      end)

    Enum.join([header | rows], "\n")
  end

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
    |> Vibe.TUI.Markdown.render(terminal_width(), Vibe.TUI.Theme.default())
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
  end

  defp terminal_width do
    case :io.columns() do
      {:ok, columns} -> columns
      _ -> 100
    end
  end
end
