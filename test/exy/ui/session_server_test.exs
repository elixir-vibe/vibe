defmodule Exy.SessionProcessTest do
  use ExUnit.Case, async: true

  test "dispatches commands, emits events, and records usage" do
    ask_fun = fn _text, _opts ->
      {:ok, %{model: "test-model", usage: %{input_tokens: 4, output_tokens: 6, total_tokens: 10}}}
    end

    {:ok, server} =
      Exy.Session.start_link(persist?: false, session_id: "ui-session", ask_fun: ask_fun)

    :ok = Exy.Session.subscribe(server)
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.Session, :event, %{type: :user_message_added}}, 500
    assert_receive {Exy.Session, :event, %{type: :assistant_message_added}}, 500
    assert_receive {Exy.Session, :event, %{type: :usage_updated}}, 500

    state = Exy.Session.state(server)
    assert Enum.map(state.messages, & &1.role) == [:user, :assistant]
    assert state.usage.total_tokens == 10
  end

  test "restores snapshot from durable UI events" do
    session_id = "restore-session-#{System.unique_integer([:positive])}"
    path = Exy.Session.Store.ui_events_path(session_id)
    on_exit(fn -> File.rm(path) end)

    {:ok, server} =
      Exy.Session.start_link(session_id: session_id, ask_fun: fn _text, _opts -> {:ok, "ok"} end)

    :ok = Exy.Session.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    GenServer.stop(server)

    {:ok, restored} =
      Exy.Session.start_link(session_id: session_id, ask_fun: fn _text, _opts -> {:ok, "ok"} end)

    assert [%{kind: :model_selector}] = Exy.Session.state(restored).overlays
    GenServer.stop(restored)
  end

  test "attach returns snapshot cursor and replays missed tail events" do
    {:ok, server} =
      Exy.Session.start_link(
        persist?: false,
        session_id: "attach-session",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Exy.Session.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    {:ok, snapshot, cursor} = Exy.Session.attach(server)

    assert [%{kind: :model_selector}] = snapshot.overlays
    assert cursor == 1

    :ok = Exy.Session.dispatch(server, {:close_overlay, %{}})
    assert_receive {Exy.Session, :event, %{type: :overlay_closed}}, 500

    {:ok, snapshot, cursor} = Exy.Session.attach(server, self(), after: 1)
    assert snapshot.overlays == []
    assert cursor == 2
    assert_receive {Exy.Session, :event, %{type: :overlay_closed}}, 500
  end

  test "default agent ask options preserve streaming callbacks" do
    on_result = fn _text -> :ok end
    on_thinking = fn _text -> :ok end

    opts =
      Exy.Session.agent_ask_opts(
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
      Exy.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Exy.Session.subscribe(server)
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.Session, :event, %{type: :assistant_delta}}, 500

    preview_state = Exy.Session.state(server)
    assert preview_state.usage.total_tokens == 0
    assert preview_state.usage_preview.total_tokens > 0
    assert Exy.UI.ViewModel.from_state(preview_state).footer.usage.total_tokens > 0

    assert_receive {Exy.Session, :event, %{type: :usage_updated}}, 500

    final_state = Exy.Session.state(server)
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
      Exy.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Exy.Session.subscribe(server)
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.Session, :event, %{type: :assistant_stream_started}}, 500
    :ok = Exy.Session.dispatch(server, :cancel_stream)

    assert_receive {Exy.Session, :event,
                    %{type: :assistant_aborted, data: %{reason: "cancelled"}}},
                   500

    refute_receive {Exy.Session, :event, %{type: :assistant_message_added}}, 100

    assert Exy.Session.state(server).status == :idle
  end

  test "records ask function crashes as assistant errors" do
    ask_fun = fn _text, _opts -> raise ArgumentError, "boom" end

    {:ok, server} =
      Exy.Session.start_link(persist?: false, session_id: "ui-session", ask_fun: ask_fun)

    :ok = Exy.Session.subscribe(server)
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.Session, :event, %{type: :assistant_aborted}}, 500
    assert_receive {Exy.Session, :event, %{type: :assistant_message_added}}, 500

    state = Exy.Session.state(server)
    assert [%{role: :user}, %{role: :assistant, error: error}] = state.messages
    assert error =~ "ArgumentError"
    assert error =~ "boom"
  end

  test "non-streaming ask functions still replace loader with final response" do
    ask_fun = fn _text, _opts -> {:ok, "done"} end

    {:ok, server} =
      Exy.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Exy.Session.subscribe(server)
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Exy.Session, :event, %{type: :assistant_stream_started}}, 500
    assert_receive {Exy.Session, :event, %{type: :assistant_message_added}}, 500

    state = Exy.Session.state(server)
    assert [%{role: :user}, %{role: :assistant, result: "done"}] = state.messages
    assert is_nil(state.streaming_message)
  end

  test "supports overlay commands" do
    {:ok, server} = Exy.Session.start_link(persist?: false, session_id: "ui-session")

    :ok = Exy.Session.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    assert [%{kind: :model_selector}] = Exy.Session.state(server).overlays

    :ok = Exy.Session.dispatch(server, :close_overlay)
    assert [] = Exy.Session.state(server).overlays
  end
end
