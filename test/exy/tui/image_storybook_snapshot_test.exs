defmodule Exy.TUI.ImageStorybookSnapshotTest do
  use ExUnit.Case, async: true

  alias Exy.TUI.Storybook

  @snapshot_dir Path.expand("../../fixtures/tui/storybook", __DIR__)

  for width <- [40, 80, 120] do
    @width width
    test "image read story plain snapshot width #{@width}" do
      assert snapshot("tool_read_image.w#{@width}.plain.txt") == render_plain(@width)
    end

    test "image read story ansi snapshot width #{@width}" do
      assert snapshot("tool_read_image.w#{@width}.ansi.txt") == render_ansi(@width)
    end
  end

  defp snapshot(name), do: File.read!(Path.join(@snapshot_dir, name))

  defp render_plain(width) do
    :tool_read_image
    |> Storybook.render_plain(width: width)
    |> Enum.join("\n")
    |> then(&(&1 <> "\n"))
  end

  defp render_ansi(width) do
    :tool_read_image
    |> Storybook.render(width: width)
    |> Enum.map_join("\n", &IO.iodata_to_binary/1)
    |> then(&(&1 <> "\n"))
  end
end
