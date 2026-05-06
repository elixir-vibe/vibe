defmodule Vibe.TUI.TraceTest do
  use ExUnit.Case, async: true

  alias Vibe.TUI.Trace

  test "audit reports frame artifacts" do
    dir = Path.join(System.tmp_dir!(), "vibe-trace-audit-#{System.unique_integer([:positive])}")
    frames_dir = Path.join(dir, "frames")
    File.mkdir_p!(frames_dir)

    File.write!(Path.join(dir, "metadata.json"), Jason.encode!(%{width: 10, height: 4}))
    File.write!(Path.join(dir, "trace.jsonl"), "")

    File.write!(
      Path.join(frames_dir, "00001.txt"),
      Enum.join(
        [
          "this line is too wide",
          "duplicate line",
          "duplicate line",
          "╭ Prompt ─╮",
          "╰──────────╯",
          "stale body"
        ],
        "\n"
      )
    )

    audit = Trace.audit(dir)

    refute audit.ok?
    assert Enum.any?(audit.issues, &(&1.check == :line_width))
    assert Enum.any?(audit.issues, &(&1.check == :adjacent_duplicate))
    assert Enum.any?(audit.issues, &(&1.check == :content_below_prompt))
    assert Enum.any?(audit.issues, &(&1.check == :frame_height))

    File.rm_rf!(dir)
  end
end
