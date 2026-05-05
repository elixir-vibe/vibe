defmodule Exy.CLI.GatewayTest do
  use ExUnit.Case, async: true

  alias Exy.CLI

  test "parses Telegram gateway options" do
    parsed =
      CLI.parse([
        "gateway",
        "telegram",
        "--foreground",
        "--token",
        "token",
        "--bot-id",
        "42",
        "--bot-username",
        "exy_bot",
        "--allow-all",
        "--require-mention",
        "--group-allowed-chats",
        "-100"
      ])

    assert parsed.args == ["gateway", "telegram"]
    assert parsed.opts[:foreground]
    assert parsed.opts[:token] == "token"
    assert parsed.opts[:bot_id] == "42"
    assert parsed.opts[:bot_username] == "exy_bot"
    assert parsed.opts[:allow_all]
    assert parsed.opts[:require_mention]
    assert parsed.opts[:group_allowed_chats] == "-100"
  end
end
