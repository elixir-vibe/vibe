defmodule Exy.Model.WebSocketSessionTest do
  use ExUnit.Case, async: false

  test "rejects providers without reusable Responses WebSocket support" do
    model = %LLMDB.Model{id: "example-model", provider: :openrouter}

    assert {:error, {:unsupported_reusable_websocket_provider, :openrouter}} =
             Exy.Model.WebSocketSession.get(model, [], "session-websocket-test")
  end

  test "closes cached sessions for a session id" do
    assert :ok = Exy.Model.WebSocketSession.close_session("session-websocket-test")
  end
end
