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
    assert image.width == 128
    assert image.height == 128
  end

  test "leaves prompts without image references unchanged" do
    assert Attachments.expand("email a@b.test and mention @missing.png", root: "/tmp") ==
             "email a@b.test and mention @missing.png"
  end
end
