defmodule Vibe.Gateway.Telegram.UpdateTest do
  use ExUnit.Case, async: true

  alias Vibe.Gateway.Telegram.Update

  test "normalizes text messages" do
    update = %{
      "update_id" => 10,
      "message" => %{
        "message_id" => 20,
        "text" => "hello",
        "chat" => %{"id" => 1, "type" => "private", "first_name" => "Dana"},
        "from" => %{"id" => 2, "first_name" => "Dana"}
      }
    }

    assert {:ok, %{message: message, trigger: trigger}} =
             Update.normalize(update, bot_username: "vibe_bot")

    assert message.text == "hello"
    assert message.type == :text
    assert message.source.chat_type == :dm
    assert message.source.chat_id == "1"
    assert message.source.user_id == "2"
    refute trigger.mentions_bot?
  end

  test "preserves private chat message_thread_id for Telegram bot topics" do
    update = %{
      message: %{
        message_id: 20,
        message_thread_id: 20,
        text: "hello",
        chat: %{id: 1, type: "private"},
        from: %{id: 2}
      }
    }

    assert {:ok, %{message: message}} = Update.normalize(update)
    assert message.source.thread_id == "20"
  end

  test "detects group mentions from Telegram entities" do
    update = %{
      message: %{
        message_id: 20,
        text: "hey @vibe_bot please",
        entities: [%{type: "mention", offset: 4, length: 9}],
        chat: %{id: -100, type: "supergroup", title: "Team"},
        from: %{id: 2, first_name: "Dana"}
      }
    }

    assert {:ok, %{message: message, trigger: trigger}} =
             Update.normalize(update, bot_username: "vibe_bot")

    assert message.source.chat_type == :group
    assert trigger.mentions_bot?
  end

  test "detects mentions using Telegram UTF-16 entity offsets" do
    update = %{
      message: %{
        message_id: 20,
        text: "😀 @vibe_bot please",
        entities: [%{type: "mention", offset: 3, length: 9}],
        chat: %{id: -100, type: "supergroup", title: "Team"},
        from: %{id: 2, first_name: "Dana"}
      }
    }

    assert {:ok, %{trigger: %{mentions_bot?: true}}} =
             Update.normalize(update, bot_username: "vibe_bot")
  end

  test "normalizes photos into Telegram file-id media placeholders" do
    update = %{
      message: %{
        message_id: 20,
        caption: "see this",
        photo: [%{file_id: "small"}, %{file_id: "large"}],
        chat: %{id: 1, type: "private"},
        from: %{id: 2}
      }
    }

    assert {:ok, %{message: message}} = Update.normalize(update)
    assert message.type == :photo
    assert message.text == "see this"
    assert [%{path: "telegram:file_id:large", mime_type: "image/jpeg"}] = message.media
  end

  test "ignores unsupported update payloads" do
    assert Update.normalize(%{callback_query: %{data: "x"}}) == :ignore
  end
end
