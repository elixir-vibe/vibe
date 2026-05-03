defmodule Exy.Model.ContentPartTest do
  use ExUnit.Case, async: true

  alias Exy.Model.Content
  alias ReqLLM.Message.ContentPart

  test "summarizes ReqLLM content parts" do
    assert Content.summarize(ContentPart.text("hello")) == "hello"
    assert Content.summarize(ContentPart.image_url("data:image/png;base64,AQID")) == "[Image]"
  end
end
