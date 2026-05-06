defmodule Vibe.CLI.Commands.TUITrace do
  @moduledoc "CLI `tui-trace` command: replay TUI trace recordings."
  alias Vibe.CLI.Output
  alias Vibe.TUI.Trace

  @behaviour Vibe.CLI.Command

  @impl true
  def names, do: ["tui-trace"]

  @impl true
  def run([_name, "summary", dir], _opts) do
    dir
    |> Trace.summary()
    |> render_summary()
    |> IO.puts()

    :ok
  end

  def run([_name, "frame", dir], opts) do
    print_frame(dir, opts[:frame] || :last)
  end

  def run([_name, "audit", dir], _opts) do
    dir
    |> Trace.audit()
    |> render_audit()
    |> IO.puts()

    :ok
  end

  def run([_name, "frame", dir, "last"], _opts), do: print_frame(dir, :last)

  def run([_name, "frame", dir, index], _opts) do
    case Integer.parse(index) do
      {index, ""} ->
        print_frame(dir, index)

      _error ->
        Output.error("Frame index must be an integer or last")
        {:error, :invalid_frame_index}
    end
  end

  def run([_name, dir], opts), do: run(["tui-trace", "summary", dir], opts)

  def run(_args, _opts) do
    IO.puts("""
    Usage:
      vibe tui-trace summary <trace-dir>
      vibe tui-trace audit <trace-dir>
      vibe tui-trace frame <trace-dir> [index | last]
      vibe tui-trace frame <trace-dir> --frame N

    Capture a trace in debug builds with:
      vibe --trace-tui /tmp/vibe-trace

    Or:
      VIBE_TUI_TRACE_DIR=/tmp/vibe-trace vibe
    """)

    :ok
  end

  defp print_frame(dir, index) do
    case Trace.frame(dir, index) do
      {:ok, text} ->
        IO.puts(text)
        :ok

      {:error, reason} ->
        Output.error("Cannot read frame: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp render_audit(%{ok?: true} = audit) do
    "Trace audit passed (#{audit.frames} frames, 0 issues)."
  end

  defp render_audit(audit) do
    header = "Trace audit found #{length(audit.issues)} issue(s) in #{audit.frames} frames."

    issues =
      Enum.map(audit.issues, fn issue ->
        location =
          [frame_label(issue.frame), line_label(issue.line)]
          |> Enum.reject(&(&1 == ""))
          |> Enum.join(" ")

        location = if location == "", do: "trace", else: location
        "#{issue.severity} #{issue.check} #{location}: #{issue.message}"
      end)

    Enum.join([header | issues], "\n")
  end

  defp frame_label(nil), do: ""
  defp frame_label(frame), do: "frame #{frame}"
  defp line_label(nil), do: ""
  defp line_label(line), do: "line #{line}"

  defp render_summary(summary) do
    metadata = summary.metadata

    [
      "Trace: #{summary.dir}",
      "Commit: #{metadata["vibe_commit"] || "-"}",
      "Session: #{metadata["session_id"] || "-"}",
      "Size: #{metadata["width"] || "?"}x#{metadata["height"] || "?"}",
      "Entries: #{summary.entries}",
      "Frames: #{summary.frames}",
      "Snapshots: #{summary.snapshots}",
      "First: #{entry_label(summary.first_entry)}",
      "Last: #{entry_label(summary.last_entry)}"
    ]
    |> Enum.join("\n")
  end

  defp entry_label(nil), do: "-"

  defp entry_label(entry) do
    seq = entry["seq"] || "?"
    type = entry["type"] || "?"
    t_us = entry["t_us"] || 0
    "##{seq} #{type} at #{Float.round(t_us / 1000, 1)}ms"
  end
end
