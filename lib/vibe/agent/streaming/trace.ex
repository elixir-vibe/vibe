defmodule Vibe.Agent.Streaming.Trace do
  @moduledoc """
  Opt-in NDJSON trace for assistant streaming order diagnostics.

  Tracing is enabled only when `VIBE_STREAM_TRACE_DIR` or
  `config :vibe, :stream_trace_dir` is set. The trace stores raw stream text for
  debugging order bugs, so callers should enable it only for local diagnostics.
  """

  @file_name "stream.ndjson"

  @doc """
  Appends one stream diagnostic event when tracing is enabled.
  """
  def record(kind, attrs \\ %{}) when is_atom(kind) and is_map(attrs) do
    with dir when is_binary(dir) and dir != "" <- trace_dir(),
         :ok <- File.mkdir_p(dir),
         {:ok, line} <- encode(kind, attrs) do
      File.write(Path.join(dir, @file_name), [line, ?\n], [:append])
    else
      _other -> :ok
    end
  end

  @doc """
  Reads trace events from `stream.ndjson` in arrival order.
  """
  def read!(dir) when is_binary(dir) do
    dir
    |> Path.join(@file_name)
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  @doc """
  Reconstructs comparable stream texts from a trace directory.

  `:runtime_text` is ordered by runtime sequence, while
  `:runtime_arrival_text` preserves file/arrival order for detecting inversions.
  """
  def compare!(dir) when is_binary(dir) do
    events = read!(dir)

    %{
      runtime_text:
        events |> Enum.filter(&(&1["kind"] == "react_runtime_delta")) |> joined_by_runtime_seq(),
      runtime_arrival_text: joined(events, "react_runtime_delta"),
      derived_text: events |> Enum.reject(& &1["suppressed?"]) |> joined("derived_llm_delta"),
      ui_text: joined(events, "ui_assistant_delta"),
      print_text: joined(events, "print_delta"),
      final_text:
        events
        |> Enum.filter(&(&1["kind"] == "ui_stream_finished"))
        |> List.last()
        |> final_text()
    }
  end

  defp joined(events, kind) do
    Enum.map_join(
      Enum.filter(events, &(&1["kind"] == kind)),
      &(&1["delta"] || &1["text"] || "")
    )
  end

  defp joined_by_runtime_seq(events) do
    events
    |> Enum.sort_by(fn event -> event["runtime_seq"] || 0 end)
    |> Enum.map_join(&(&1["delta"] || ""))
  end

  defp final_text(nil), do: ""
  defp final_text(event), do: event["text"] || ""

  defp encode(kind, attrs) do
    Jason.encode(
      attrs
      |> Map.put(:kind, kind)
      |> Map.put(:at_ms, System.system_time(:millisecond))
      |> Map.put(:pid, inspect(self()))
    )
  end

  defp trace_dir do
    System.get_env("VIBE_STREAM_TRACE_DIR") || Application.get_env(:vibe, :stream_trace_dir)
  end
end
