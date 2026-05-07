defmodule Vibe.TUI.CastTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.Cast
  alias Vibe.TUI.Cast.Writer

  test "records native gzip ETF blocks and replays plain snapshots" do
    path = tmp_path("basic.vibe-tui.etf.gz")

    {:ok, writer} = Writer.start_link(path: path, width: 20, height: 5, session_id: "cast-test")
    :ok = Writer.output(writer, "hello")
    :ok = Writer.output(writer, "\r\nworld")
    :ok = Writer.input_redacted(writer, 12)
    :ok = Writer.resize(writer, 30, 6)
    :ok = Writer.close(writer)

    assert File.exists?(path)
    assert File.exists?(path <> ".idx.etf.gz")

    assert {:ok, cast} = Cast.open(path)
    assert %{session_id: "cast-test", width: 20, height: 5, output_events: 2} = Cast.info(cast)

    assert {:input_redacted, _t_us, 12} =
             Enum.find(Cast.events(cast), &(elem(&1, 0) == :input_redacted))

    assert {:resize, _t_us, 30, 6} = Enum.find(Cast.events(cast), &(elem(&1, 0) == :resize))

    assert {:ok, snapshot} = Cast.snapshot(cast, format: :plain)
    assert snapshot =~ "hello"
    assert snapshot =~ "world"
  end

  test "exports asciinema v2 jsonl" do
    path = tmp_path("export.vibe-tui.etf.gz")
    cast_path = tmp_path("export.cast")

    {:ok, writer} = Writer.start_link(path: path, width: 10, height: 4, session_id: "cast-export")
    :ok = Writer.output(writer, "hi")
    :ok = Writer.input(writer, "x")
    :ok = Writer.close(writer)

    assert :ok = Cast.export_asciinema(path, cast_path)

    [header_line, output_line, input_line] =
      File.read!(cast_path) |> String.split("\n", trim: true)

    assert %{"version" => 2, "width" => 10, "height" => 4} = Jason.decode!(header_line)
    assert [_, "o", "hi"] = Jason.decode!(output_line)
    assert [_, "i", "x"] = Jason.decode!(input_line)
  end

  test "find locates visual text over replayed snapshots" do
    path = tmp_path("find.vibe-tui.etf.gz")

    {:ok, writer} = Writer.start_link(path: path, width: 20, height: 5, session_id: "cast-find")
    :ok = Writer.output(writer, "first")
    Process.sleep(2)
    :ok = Writer.output(writer, "\r\nneedle")
    :ok = Writer.close(writer)

    assert [%{match: "needle"} | _] = Cast.find(path, "needle", every_ms: 1)
  end

  defp tmp_path(name) do
    dir = Path.join(System.tmp_dir!(), "vibe-cast-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Path.join(dir, name)
  end
end
