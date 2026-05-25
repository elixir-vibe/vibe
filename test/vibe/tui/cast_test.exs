defmodule Vibe.TUI.CastTest do
  use ExUnit.Case, async: false

  alias Vibe.TUI.Cast
  alias Vibe.TUI.Cast.Writer

  test "records TTYCast chunks and replays plain snapshots" do
    path = tmp_path("basic.ttycast")

    {:ok, writer} = Writer.start_link(path: path, width: 20, height: 5, session_id: "cast-test")
    :ok = Writer.output(writer, "hello")
    :ok = Writer.output(writer, "\r\nworld")
    :ok = TTYCast.Writer.input_redacted(writer, 12)
    :ok = TTYCast.Writer.resize(writer, 30, 6)
    :ok = TTYCast.Writer.close(writer)

    assert File.exists?(path)
    assert File.exists?(path <> ".live.idx")

    assert {:ok, cast} = Cast.open(path)
    assert %{width: 20, height: 5, events: 4} = TTYCast.info(cast)

    assert {:input_redacted, _t_us, 12} =
             Enum.find(TTYCast.events(cast), &(elem(&1, 0) == :input_redacted))

    assert {:resize, _t_us, 30, 6} = Enum.find(TTYCast.events(cast), &(elem(&1, 0) == :resize))

    assert {:ok, snapshot} = TTYCast.snapshot(cast, format: :plain)
    assert snapshot =~ "hello"
    assert snapshot =~ "world"
  end

  test "exports asciinema v2 jsonl" do
    path = tmp_path("export.ttycast")
    cast_path = tmp_path("export.cast")

    {:ok, writer} =
      Writer.start_link(
        path: path,
        width: 10,
        height: 4,
        session_id: "cast-export",
        record_input: true
      )

    :ok = Writer.output(writer, "hi")
    :ok = TTYCast.Writer.input(writer, "x")
    :ok = TTYCast.Writer.close(writer)

    assert :ok = Cast.export_asciinema(path, cast_path)

    [header_line, output_line, input_line] =
      File.read!(cast_path) |> String.split("\n", trim: true)

    assert %{"version" => 2, "width" => 10, "height" => 4} = Jason.decode!(header_line)
    assert [_, "o", "hi"] = Jason.decode!(output_line)
    assert [_, "i", "x"] = Jason.decode!(input_line)
  end

  test "find locates visual text over replayed snapshots" do
    path = tmp_path("find.ttycast")

    {:ok, writer} = Writer.start_link(path: path, width: 20, height: 5, session_id: "cast-find")
    :ok = Writer.output(writer, "first")
    :ok = Writer.output(writer, "\r\nneedle")
    :ok = TTYCast.Writer.close(writer)

    assert [%{match: "needle"} | _] = TTYCast.find(path, "needle", every_ms: 1)
  end

  test "path generation uses ttycast extension" do
    dir = tmp_path("casts")
    File.mkdir_p!(dir)

    previous = System.get_env("VIBE_TUI_CAST_DIR")
    System.put_env("VIBE_TUI_CAST_DIR", dir)

    on_exit(fn ->
      if previous,
        do: System.put_env("VIBE_TUI_CAST_DIR", previous),
        else: System.delete_env("VIBE_TUI_CAST_DIR")
    end)

    assert Cast.path_from_opts(session_id: "abc") =~ ~r/abc\.ttycast$/
  end

  defp tmp_path(name) do
    dir = Path.join(System.tmp_dir!(), "vibe-cast-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    Path.join(dir, name)
  end
end
