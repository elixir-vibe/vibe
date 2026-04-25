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

  test "default agent ask options preserve streaming callbacks" do
    on_result = fn _text -> :ok end
    on_thinking = fn _text -> :ok end

    opts =
      Exy.UI.SessionServer.agent_ask_opts(
        model: "test-model",
        session_id: "ui-session",
        on_result: on_result,
        on_thinking: on_thinking,
        timeout: 123
      )

    refute Keyword.has_key?(opts, :model)
    assert opts[:session_id] == "ui-session"
    assert opts[:on_result] == on_result
    assert opts[:on_thinking] == on_thinking
    assert opts[:timeout] == 123
  end

  test "updates token preview from streaming callbacks before final usage" do
    ask_fun = fn _text, opts ->
      opts[:on_result].("streaming text")
      Process.sleep(20)

      {:ok,
       %{
         output: "streaming text",
         usage: %{input_tokens: 10, output_tokens: 20, total_tokens: 30}
       }}
    end

    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Exy.UI.SessionServer.subscribe(server)
    :ok = Exy.UI.SessionServer.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_delta}}, 500

    preview_state = Exy.UI.SessionServer.state(server)
    assert preview_state.usage.total_tokens == 0
    assert preview_state.usage_preview.total_tokens > 0
    assert Exy.UI.ViewModel.from_state(preview_state).footer.usage.total_tokens > 0

    assert_receive {Exy.UI.SessionServer, :event, %{type: :usage_updated}}, 500

    final_state = Exy.UI.SessionServer.state(server)
    assert final_state.usage.total_tokens == 30
    assert final_state.usage_preview.total_tokens == 0
    assert Exy.UI.ViewModel.from_state(final_state).footer.usage.total_tokens == 30
  end

  test "cancel aborts active prompt task and ignores late results" do
    ask_fun = fn _text, _opts ->
      Process.sleep(5_000)
      {:ok, "too late"}
    end

    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Exy.UI.SessionServer.subscribe(server)
    :ok = Exy.UI.SessionServer.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_stream_started}}, 500
    :ok = Exy.UI.SessionServer.dispatch(server, :cancel_stream)

    assert_receive {Exy.UI.SessionServer, :event,
                    %{type: :assistant_aborted, data: %{reason: "cancelled"}}},
                   500

    refute_receive {Exy.UI.SessionServer, :event, %{type: :assistant_message_added}}, 100

    assert Exy.UI.SessionServer.state(server).status == :idle
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

  test "non-streaming ask functions still replace loader with final response" do
    ask_fun = fn _text, _opts -> {:ok, "done"} end

    {:ok, server} =
      Exy.UI.SessionServer.start_link(
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Exy.UI.SessionServer.subscribe(server)
    :ok = Exy.UI.SessionServer.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_stream_started}}, 500
    assert_receive {Exy.UI.SessionServer, :event, %{type: :assistant_message_added}}, 500

    state = Exy.UI.SessionServer.state(server)
    assert [%{role: :user}, %{role: :assistant, result: "done"}] = state.messages
    assert is_nil(state.streaming_message)
  end

  test "supports overlay commands" do
    {:ok, server} = Exy.UI.SessionServer.start_link(session_id: "ui-session")

    :ok = Exy.UI.SessionServer.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    assert [%{kind: :model_selector}] = Exy.UI.SessionServer.state(server).overlays

    :ok = Exy.UI.SessionServer.dispatch(server, :close_overlay)
    assert [] = Exy.UI.SessionServer.state(server).overlays
  end
end
