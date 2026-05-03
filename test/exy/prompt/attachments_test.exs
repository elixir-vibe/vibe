defmodule Exy.Prompt.AttachmentsTest do
  use ExUnit.Case, async: true

  alias Exy.Model.Content
  alias Exy.Prompt.Attachments

  test "expands image references into multimodal content" do
    root = Path.expand("../../fixtures/images", __DIR__)

    assert [%Content.Text{text: text}, %Content.Image{} = image] =
             Attachments.expand("describe @vision-smoke.png please", root: root)

    assert text == "describe  please"
    assert image.mime_type == "image/png"
    assert image.filename == "vision-smoke.png"
    assert image.width == 320
    assert image.height == 200
  end

  test "expands quoted image references" do
    root = Path.join(System.tmp_dir!(), "exy-attachments-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    File.cp!(
      Path.expand("../../fixtures/images/vision-smoke.png", __DIR__),
      Path.join(root, "space name.png")
    )

    try do
      assert [%Content.Text{text: "describe"}, %Content.Image{filename: "space name.png"}] =
               Attachments.expand(~s(describe @"space name.png"), root: root)
    after
      File.rm_rf(root)
    end
  end

  test "preserves quoted non-image references in fallback" do
    assert Attachments.expand(~s(describe @"missing file.txt" please), root: "/tmp") ==
             ~s(describe @"missing file.txt" please)
  end

  test "escapes special characters in file blocks" do
    root = Path.join(System.tmp_dir!(), "exy-attachments-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    File.write!(Path.join(root, "a&b.txt"), "x < y")

    try do
      assert {:ok, %{text: text}} =
               Attachments.process_file_args(["a&b.txt"], root: root)

      assert text =~ "a&amp;b.txt"
      assert text =~ "x &lt; y"
      refute text =~ "<file name=\"" <> Path.join(root, "a&b.txt")
    after
      File.rm_rf(root)
    end
  end

  test "leaves prompts without image references unchanged" do
    assert Attachments.expand("email a@b.test and mention @missing.png", root: "/tmp") ==
             "email a@b.test and mention @missing.png"
  end
end
