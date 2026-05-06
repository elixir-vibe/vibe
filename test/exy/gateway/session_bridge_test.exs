defmodule Exy.Gateway.SessionBridgeTest do
  use ExUnit.Case, async: true

  alias Exy.Gateway.{Message, SessionBridge, Source}
  alias Exy.UI.Event

  test "streams assistant deltas to the gateway adapter" do
    parent = self()
    session_id = "gateway-bridge-#{System.unique_integer([:positive])}"

    assert {:ok, session} =
             Exy.Session.start(session_id: session_id, ask_fun: fn _, _ -> {:ok, "unused"} end)

    message =
      Message.new(Source.new(:telegram, chat_id: "chat-1", chat_type: :dm, user_id: "user-1"),
        text: "hello",
        id: "reply-1"
      )

    assert {:ok, _bridge} =
             SessionBridge.start(message, session_id,
               adapter: Exy.Test.GatewayRecordingAdapter,
               adapter_opts: [owner: parent, message_id: "out-1"],
               consumer_opts: [buffer_threshold: 1, edit_interval_ms: 60_000]
             )

    Exy.Session.emit_event(session, Event.new(:assistant_stream_started, session_id, %{}))
    Exy.Session.emit_event(session, Event.new(:assistant_delta, session_id, %{text: "hi"}))

    assert_receive {:gateway_send, "chat-1", "hi ▉", opts}
    assert opts[:reply_to] == "reply-1"

    Exy.Session.emit_event(session, Event.new(:assistant_delta, session_id, %{text: " there"}))
    assert_receive {:gateway_edit, "chat-1", "out-1", "hi there ▉", _opts}

    Exy.Session.emit_event(
      session,
      Event.new(:assistant_stream_finished, session_id, %{text: "hi there"})
    )

    assert_receive {:gateway_edit, "chat-1", "out-1", "hi there", opts}
    assert opts[:finalize?]
  end

  test "sends ReqLLM response text from non-streaming assistant messages" do
    parent = self()
    session_id = "gateway-bridge-#{System.unique_integer([:positive])}"

    assert {:ok, session} =
             Exy.Session.start(session_id: session_id, ask_fun: fn _, _ -> {:ok, "unused"} end)

    message =
      Message.new(Source.new(:telegram, chat_id: "chat-1", chat_type: :dm, user_id: "user-1"),
        id: "reply-1"
      )

    response = %ReqLLM.Response{
      id: "response-1",
      model: "test",
      context: nil,
      message: %ReqLLM.Message{
        role: :assistant,
        content: [ReqLLM.Message.ContentPart.text("from response")]
      }
    }

    assert {:ok, _bridge} =
             SessionBridge.start(message, session_id,
               adapter: Exy.Test.GatewayRecordingAdapter,
               adapter_opts: [owner: parent]
             )

    Exy.Session.emit_event(
      session,
      Event.new(:assistant_message_added, session_id, %{result: response})
    )

    assert_receive {:gateway_send, "chat-1", "from response", _opts}
  end

  test "sends non-streaming assistant messages" do
    parent = self()
    session_id = "gateway-bridge-#{System.unique_integer([:positive])}"

    assert {:ok, session} =
             Exy.Session.start(session_id: session_id, ask_fun: fn _, _ -> {:ok, "unused"} end)

    message =
      Message.new(Source.new(:telegram, chat_id: "chat-1", chat_type: :dm, user_id: "user-1"),
        id: "reply-1"
      )

    assert {:ok, _bridge} =
             SessionBridge.start(message, session_id,
               adapter: Exy.Test.GatewayRecordingAdapter,
               adapter_opts: [owner: parent]
             )

    Exy.Session.emit_event(
      session,
      Event.new(:assistant_message_added, session_id, %{result: %{output: "done"}})
    )

    assert_receive {:gateway_send, "chat-1", "done", opts}
    assert opts[:reply_to] == "reply-1"
  end
end
