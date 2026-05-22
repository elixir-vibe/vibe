defmodule Vibe.CLI.Output.Renderer do
  @moduledoc false

  alias IO.ANSI
  alias ReqLLM.Response
  alias Vibe.Eval.Result, as: EvalResult
  alias Vibe.Storage.Search
  alias Vibe.Subagents.{JobInfo, Schedule}

  @spec render(term()) :: String.t()
  def render([]), do: "No results."

  def render([%Search.Result{} | _rest] = results), do: render_search_results(results)
  def render([%JobInfo{} | _rest] = jobs), do: render_jobs(jobs)
  def render([%Schedule{} | _rest] = schedules), do: render_schedules(schedules)

  def render([first | _rest] = sessions) when is_map(first) do
    if session_listing?(first), do: render_sessions(sessions), else: render_list(sessions)
  end

  def render(results) when is_list(results), do: render_list(results)

  def render(%Response{} = response), do: response |> Response.text() |> render_markdown()
  def render(%EvalResult{format: :markdown, output: output}), do: render_markdown(output)
  def render(%EvalResult{output: output}), do: output
  def render(%{summary: summary}), do: render_markdown(summary)
  def render(%{output: output}), do: output
  def render(result) when is_binary(result), do: render_markdown(result)
  def render(result), do: inspect(result, pretty: true, limit: 50)

  defp render_list(results),
    do: Enum.map_join(results, "\n", &inspect(&1, pretty: true, limit: 20))

  defp session_listing?(session) do
    Map.has_key?(session, :id) and
      (Map.has_key?(session, :updated_at) or Map.has_key?(session, :first_message) or
         Map.has_key?(session, :last_message_preview))
  end

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
        highlight_search_result(result)
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

  defp highlight_search_result(%{snippet_parts: [_ | _] = parts}) do
    parts
    |> Enum.map(fn
      %{text: text, highlight?: true} ->
        [ANSI.yellow(), ANSI.bright(), cli_snippet_text(text), ANSI.reset()]

      %{text: text} ->
        cli_snippet_text(text)
    end)
    |> IO.iodata_to_binary()
  end

  defp highlight_search_result(result), do: cli_snippet_text(result.snippet || result.text)
  defp cli_snippet_text(text), do: String.replace(to_string(text || ""), "…", "...")

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
