defmodule Exy.Gateway.Telegram.PollingTest do
  use ExUnit.Case, async: true

  alias Exy.Gateway.Telegram.{Config, Polling}

  test "clears stale webhook and submits fetched updates to runtime" do
    parent = self()
    {:ok, calls} = Agent.start_link(fn -> 0 end)
    config = %Config{token: "token"}

    fetch = fn opts ->
      send(parent, {:fetch_opts, opts})

      case Agent.get_and_update(calls, fn count -> {count, count + 1} end) do
        0 -> [%{"update_id" => 10, "message" => %{}}]
        _later -> []
      end
    end

    delete_webhook = fn opts ->
      send(parent, {:delete_webhook, opts})
      {:ok, true}
    end

    assert {:ok, polling} =
             Polling.start_link(
               config: config,
               runtime: self(),
               interval_ms: 60_000,
               timeout_s: 1,
               fetch_fun: fetch,
               delete_webhook_fun: delete_webhook
             )

    assert_receive {:delete_webhook, [token: "token"]}
    assert_receive {:fetch_opts, opts}
    assert opts[:token] == "token"
    assert opts[:offset] == -1
    assert opts[:timeout] == 1
    assert_receive {:"$gen_cast", {:update, %{"update_id" => 10}}}

    send(polling, :poll)
    assert_receive {:fetch_opts, opts}
    assert opts[:offset] == 11
  end
end
