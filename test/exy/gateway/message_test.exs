defmodule Exy.Gateway.MessageTest do
  use ExUnit.Case, async: true

  alias Exy.Gateway.{Message, Source}

  test "extracts commands without bot suffix" do
    source = Source.new(:telegram, chat_id: "1")
    message = Message.new(source, text: "/model@exy_bot openai:gpt-5", type: :command)

    assert Message.command?(message)
    assert Message.command(message) == "model"
    assert Message.command_args(message) == "openai:gpt-5"
  end

  test "normalizes media entries" do
    source = Source.new(:telegram, chat_id: "1")
    message = Message.new(source, media: [%{"path" => "/tmp/a.png", "mime_type" => "image/png"}])

    assert [%{path: "/tmp/a.png", mime_type: "image/png"}] = message.media
  end
end
