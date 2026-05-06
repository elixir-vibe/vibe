defmodule Vibe.Gateway.Telegram.StreamConsumerTest do
  use ExUnit.Case, async: true

  alias Vibe.Gateway.Telegram.{Config, StreamConsumer}

  test "sends partial text as Telegram drafts and final text as a message" do
    parent = self()

    draft_fun = fn chat_id, draft_id, text, opts ->
      send(parent, {:draft, chat_id, draft_id, text, opts})
      {:ok, true}
    end

    assert {:ok, consumer} =
             StreamConsumer.start_link(
               adapter: Vibe.Test.GatewayRecordingAdapter,
               chat_id: "123",
               adapter_opts: [owner: parent, config: %Config{token: "token"}],
               draft_fun: draft_fun,
               draft_id: 77,
               buffer_threshold: 1,
               edit_interval_ms: 60_000,
               reply_to: "reply-1"
             )

    StreamConsumer.delta(consumer, "**hel**")
    assert_receive {:draft, 123, 77, "<b>hel</b>", opts}
    assert opts[:token] == "token"
    assert opts[:parse_mode] == "HTML"

    StreamConsumer.delta(consumer, "lo")
    assert_receive {:draft, 123, 77, "<b>hel</b>lo", opts}
    assert opts[:token] == "token"
    assert opts[:parse_mode] == "HTML"

    StreamConsumer.finish(consumer)
    assert_receive {:gateway_send, "123", "**hel**lo", opts}
    assert opts[:reply_to] == "reply-1"
  end
end
