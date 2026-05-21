defmodule Vibe.Gateway.StreamConsumerTest do
  use ExUnit.Case, async: true

  alias Vibe.Gateway.StreamConsumer

  test "sends initial text with cursor and finalizes by editing without cursor" do
    {:ok, pid} =
      StreamConsumer.start_link(
        adapter: Vibe.Test.GatewayAdapter,
        chat_id: "chat-1",
        adapter_opts: [owner: self()],
        edit_interval_ms: 10_000,
        buffer_threshold: 5,
        cursor: " ▉"
      )

    StreamConsumer.delta(pid, "hello")
    assert_receive {:gateway_send, "chat-1", message_id, "hello ▉", _opts}

    StreamConsumer.finish(pid)
    assert_receive {:gateway_edit, "chat-1", ^message_id, "hello", opts}
    assert Keyword.get(opts, :finalize?) == true
  end

  test "coalesces small deltas until the interval fires" do
    {:ok, pid} =
      StreamConsumer.start_link(
        adapter: Vibe.Test.GatewayAdapter,
        chat_id: "chat-1",
        adapter_opts: [owner: self()],
        edit_interval_ms: 20,
        buffer_threshold: 100,
        cursor: " ▉"
      )

    StreamConsumer.delta(pid, "he")
    refute_receive {:gateway_send, _, _, _, _}, 5
    StreamConsumer.delta(pid, "llo")
    assert_receive {:gateway_send, "chat-1", _message_id, "hello ▉", _opts}, 1_000
  end

  test "segment break finalizes current message and starts a new one" do
    {:ok, pid} =
      StreamConsumer.start_link(
        adapter: Vibe.Test.GatewayAdapter,
        chat_id: "chat-1",
        adapter_opts: [owner: self()],
        edit_interval_ms: 10_000,
        buffer_threshold: 4,
        cursor: " ▉"
      )

    StreamConsumer.delta(pid, "tool")
    assert_receive {:gateway_send, "chat-1", first_id, "tool ▉", _opts}, 1_000

    StreamConsumer.segment_break(pid)
    assert_receive {:gateway_edit, "chat-1", ^first_id, "tool", _opts}, 1_000

    StreamConsumer.delta(pid, "done")
    assert_receive {:gateway_send, "chat-1", second_id, "done ▉", _opts}, 1_000
    refute first_id == second_id
  end

  test "filters internal media directives from display text" do
    assert StreamConsumer.filter_display_text("see MEDIA:/tmp/a.png\n[[audio_as_voice]] done") ==
             "see \n done"
  end
end
