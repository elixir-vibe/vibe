defmodule Exy.Agent.Streaming.Trace do
  @moduledoc false

  @file_name "stream.ndjson"

  def record(kind, attrs \\ %{}) when is_atom(kind) and is_map(attrs) do
    with dir when is_binary(dir) and dir != "" <- trace_dir(),
         :ok <- File.mkdir_p(dir),
         {:ok, line} <- encode(kind, attrs) do
      File.write(Path.join(dir, @file_name), [line, ?\n], [:append])
    else
      _other -> :ok
    end
  end

  def read!(dir) when is_binary(dir) do
    dir
    |> Path.join(@file_name)
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

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
    events
    |> Enum.filter(&(&1["kind"] == kind))
    |> Enum.map(&(&1["delta"] || &1["text"] || ""))
    |> Enum.join("")
  end

  defp joined_by_runtime_seq(events) do
    events
    |> Enum.sort_by(fn event -> event["runtime_seq"] || 0 end)
    |> Enum.map(&(&1["delta"] || ""))
    |> Enum.join("")
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
    System.get_env("EXY_STREAM_TRACE_DIR") || Application.get_env(:exy, :stream_trace_dir)
  end
end
