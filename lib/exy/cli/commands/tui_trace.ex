defmodule Exy.CLI.Commands.TUITrace do
  @moduledoc false

  alias Exy.CLI.Output
  alias Exy.TUI.Trace

  @behaviour Exy.CLI.Command

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

  def run([_name, "frame", dir, index], _opts) do
    case Integer.parse(index) do
      {index, ""} ->
        print_frame(dir, index)

      _error ->
        Output.error("Frame index must be an integer")
        {:error, :invalid_frame_index}
    end
  end

  def run([_name, dir], opts), do: run(["tui-trace", "summary", dir], opts)

  def run(_args, _opts) do
    IO.puts("""
    Usage:
      exy tui-trace summary <trace-dir>
      exy tui-trace frame <trace-dir> [index]
      exy tui-trace frame <trace-dir> --frame N

    Capture a trace in debug builds with:
      exy --trace-tui /tmp/exy-trace

    Or:
      EXY_TUI_TRACE_DIR=/tmp/exy-trace exy
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

  defp render_summary(summary) do
    metadata = summary.metadata

    [
      "Trace: #{summary.dir}",
      "Commit: #{metadata["exy_commit"] || "-"}",
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
