defmodule Exy.UI.SessionServerTest do
  use ExUnit.Case, async: true

  test "dispatches commands, emits events, and records usage" do
    ask_fun = fn _text, _opts ->
      {:ok, %{model: "test-model", usage: %{input_tokens: 4, output_tokens: 6, total_tokens: 10}}}
    end

    {:ok, server} = Exy.UI.SessionServer.start_link(session_id: "ui-session", ask_fun: ask_fun)
    :ok = Exy.UI.SessionServer.subscribe(server)
    :ok = Exy.UI.SessionServer.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.UI.SessionServer, :event, %{type: :user_message_added}}, 500
    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_message_added}}, 500
    assert_receive {Exy.UI.SessionServer, :event, %{type: :usage_updated}}, 500

    state = Exy.UI.SessionServer.state(server)
    assert Enum.map(state.messages, & &1.role) == [:user, :assistant]
    assert state.usage.total_tokens == 10
  end

  test "records ask function crashes as assistant errors" do
    ask_fun = fn _text, _opts -> raise ArgumentError, "boom" end

    {:ok, server} = Exy.UI.SessionServer.start_link(session_id: "ui-session", ask_fun: ask_fun)
    :ok = Exy.UI.SessionServer.subscribe(server)
    :ok = Exy.UI.SessionServer.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_aborted}}, 500
    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_message_added}}, 500

    state = Exy.UI.SessionServer.state(server)
    assert [%{role: :user}, %{role: :assistant, error: error}] = state.messages
    assert error =~ "ArgumentError"
    assert error =~ "boom"
  end

  test "supports overlay commands" do
    {:ok, server} = Exy.UI.SessionServer.start_link(session_id: "ui-session")

    :ok = Exy.UI.SessionServer.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    assert [%{kind: :model_selector}] = Exy.UI.SessionServer.state(server).overlays

    :ok = Exy.UI.SessionServer.dispatch(server, :close_overlay)
    assert [] = Exy.UI.SessionServer.state(server).overlays
  end
end
