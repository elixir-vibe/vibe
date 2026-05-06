defmodule Exy.Gateway.Telegram.ConfigTest do
  use ExUnit.Case, async: false

  alias Exy.Gateway.Telegram.Config

  setup do
    keys =
      ~w(TELEGRAM_BOT_TOKEN TELEGRAM_WEBHOOK_URL TELEGRAM_WEBHOOK_SECRET TELEGRAM_ALLOWED_USERS)

    previous = Map.new(keys, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    Enum.each(keys, &System.delete_env/1)
    :ok
  end

  test "requires token" do
    assert Config.load() == {:error, :telegram_token_required}
  end

  test "loads polling config from overrides" do
    assert {:ok, config} = Config.load(token: "token", allowed_users: "1,2", stream_mode: "draft")
    assert config.method == :polling
    assert config.stream_mode == :draft
    assert config.poll_max_consecutive_conflicts == 12
    assert MapSet.equal?(config.allowed_users, MapSet.new(["1", "2"]))
  end

  test "loads polling conflict limit from overrides" do
    assert {:ok, config} = Config.load(token: "token", poll_max_consecutive_conflicts: "3")
    assert config.poll_max_consecutive_conflicts == 3
  end

  test "requires webhook secret for webhook mode" do
    assert Config.load(token: "token", method: :webhook, webhook_url: "https://example.test/tg") ==
             {:error, :telegram_webhook_secret_required}
  end
end
