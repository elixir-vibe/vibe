defmodule Vibe.Web.Presentation.Tool.BodyProjectionTest do
  use ExUnit.Case, async: true

  alias Vibe.Model.Content
  alias Vibe.Web.Presentation.Tool.BodyProjection

  test "projects markdown source diff and text blocks" do
    markdown = BodyProjection.block({:markdown, "**hi**", []}, true)
    assert markdown.kind == :markdown
    assert markdown.label == "Markdown"
    assert markdown.html =~ "hi"

    source = BodyProjection.block({:source, "<tag>", language: :elixir}, true)
    assert source.kind == :source_html
    assert source.label == "ELIXIR"
    refute source.html =~ "<tag>"

    diff = BodyProjection.block({:diff, "+<tag>", []}, true)
    assert diff.kind == :diff_html
    diff_html = IO.iodata_to_binary(diff.html)
    refute diff_html =~ "+<tag>"
    assert diff_html =~ "+&lt;tag&gt;"

    text = BodyProjection.block({:text, "\e[31mred\e[0m", []}, true)
    assert text.kind == :text
    assert text.text == "red"
  end

  test "projects lines fallback and images" do
    assert BodyProjection.block({:lines, [["a"], "b"], []}, true).text == "a\nb"
    assert BodyProjection.block({:unknown, :value}, true).kind == :inspect

    image = %Content.Image{data: Base.encode64("abc"), mime_type: "image/png", filename: nil}
    body = BodyProjection.block({:image, image, []}, true)

    assert body.kind == :image
    assert body.src =~ "data:image/png;base64,"
    assert body.alt == "Image"
  end
end
