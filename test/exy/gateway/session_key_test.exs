defmodule Exy.Gateway.SessionKeyTest do
  use ExUnit.Case, async: true

  alias Exy.Gateway.{SessionKey, Source}

  test "DM keys are isolated by chat and thread" do
    source = Source.new(:telegram, chat_id: "10", chat_type: :dm, thread_id: "3")

    assert SessionKey.build(source) == "gateway:telegram:dm:10:3"
  end

  test "group keys default to per-user isolation" do
    source = Source.new(:telegram, chat_id: "-100", chat_type: :group, user_id: "42")

    assert SessionKey.build(source) == "gateway:telegram:group:-100:42"

    assert SessionKey.build(source, group_sessions_per_user: false) ==
             "gateway:telegram:group:-100"
  end

  test "threaded group keys default to shared topic sessions" do
    source =
      Source.new(:telegram,
        chat_id: "-100",
        chat_type: :group,
        thread_id: "77",
        user_id: "42"
      )

    assert SessionKey.build(source) == "gateway:telegram:group:-100:77"

    assert SessionKey.build(source, thread_sessions_per_user: true) ==
             "gateway:telegram:group:-100:77:42"
  end
end
