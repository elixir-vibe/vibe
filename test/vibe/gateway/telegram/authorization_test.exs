defmodule Vibe.Gateway.Telegram.AuthorizationTest do
  use ExUnit.Case, async: true

  alias Vibe.Gateway.Source
  alias Vibe.Gateway.Telegram.{Authorization, Config}

  test "authorizes allowed DM users" do
    source = Source.new(:telegram, chat_id: "10", chat_type: :dm, user_id: "42")
    config = %Config{token: "token", allowed_users: MapSet.new(["42"])}

    assert Authorization.authorized?(source, config)
  end

  test "authorizes group chats by chat allowlist" do
    source = Source.new(:telegram, chat_id: "-100", chat_type: :group, user_id: "42")
    config = %Config{token: "token", group_allowed_chats: MapSet.new(["-100"])}

    assert Authorization.authorized?(source, config)
  end

  test "group trigger gate can require mention or reply" do
    source = Source.new(:telegram, chat_id: "-100", chat_type: :group, user_id: "42")
    config = %Config{token: "token", require_mention?: true}

    refute Authorization.trigger_allowed?(source, %{}, config)
    assert Authorization.trigger_allowed?(source, %{mentions_bot?: true}, config)
    assert Authorization.trigger_allowed?(source, %{reply_to_bot?: true}, config)
  end

  test "ignored threads are dropped before mention rules" do
    source =
      Source.new(:telegram, chat_id: "-100", chat_type: :group, thread_id: "7", user_id: "42")

    config = %Config{
      token: "token",
      ignored_threads: MapSet.new([7]),
      free_response_chats: MapSet.new(["-100"])
    }

    refute Authorization.trigger_allowed?(source, %{mentions_bot?: true}, config)
  end
end
