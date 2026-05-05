defmodule Exy.SessionProcessTest do
  use ExUnit.Case, async: true

  @late_prompt_sleep_ms 5_000

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

  test "semantic prompt content is preserved in UI events" do
    prompt = [
      Exy.Model.Content.text("describe"),
      Exy.Model.Content.image(data: Base.encode64(<<1, 2, 3>>), mime_type: "image/png")
    ]

    {:ok, server} =
      Exy.Session.start_link(
        persist?: false,
        session_id: "semantic-content-session",
        ask_fun: fn text, _opts -> {:ok, text} end
      )

    :ok = Exy.Session.subscribe(server)
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{content: prompt}})

    assert_receive {Exy.Session, :event,
                    %{type: :user_message_added, data: %{content: ^prompt, image_count: 1}}},
                   500

    assert [%{role: :user, content: ^prompt, image_count: 1} | _] =
             Exy.Session.state(server).messages
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

  test "attach can replay missed events from durable log before in-memory tail" do
    session_id = "durable-replay-#{System.unique_integer([:positive])}"
    path = Exy.Session.Store.path(session_id)
    on_exit(fn -> File.rm(path) end)

    {:ok, server} =
      Exy.Session.start_link(session_id: session_id, ask_fun: fn _text, _opts -> {:ok, "ok"} end)

    for index <- 1..205 do
      :ok =
        Exy.Session.emit_event(
          server,
          Exy.UI.Event.new(:notification_added, session_id, %{id: index, text: "n#{index}"})
        )
    end

    {:ok, _snapshot, 205} = Exy.Session.attach(server, self(), after: 1)
    assert_receive {Exy.Session, :event, %{data: %{id: 2}}}
    assert_receive {Exy.Session, :event, %{data: %{id: 3}}}
    GenServer.stop(server)
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

  test "cycles model and effort through session commands" do
    {:ok, server} =
      Exy.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        model: "openai_codex:gpt-5.5",
        effort: :medium,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Exy.Session.dispatch(server, {:cycle_model, %{direction: :forward}})
    :ok = Exy.Session.dispatch(server, :cycle_effort)

    state = Exy.Session.state(server)
    assert state.model != "openai_codex:gpt-5.5"
    assert state.effort == :high
  end

  test "opens model and effort selectors through session commands" do
    {:ok, server} =
      Exy.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        model: "openai_codex:gpt-5.5",
        effort: :medium,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Exy.Session.dispatch(server, :open_model_selector)
    assert Exy.Session.state(server).selector.kind == :model_selector

    :ok = Exy.Session.dispatch(server, :open_effort_selector)
    state = Exy.Session.state(server)
    assert state.selector.kind == :effort_selector
    assert state.selector.items == ["off", "minimal", "low", "medium", "high", "xhigh"]
    assert state.selector.selected == 3
  end

  test "passes selected model and effort into prompt options" do
    parent = self()

    ask_fun = fn _text, opts ->
      send(parent, {:ask_opts, opts})
      {:ok, "ok"}
    end

    {:ok, server} =
      Exy.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        model: "model-a",
        effort: :medium,
        ask_fun: ask_fun
      )

    :ok = Exy.Session.dispatch(server, {:model_selected, %{model: "model-b"}})
    :ok = Exy.Session.dispatch(server, {:effort_selected, %{effort: :high}})
    :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {:ask_opts, opts}, 500
    assert opts[:model] == "model-b"
    assert opts[:effort] == :high
    assert opts[:llm_opts][:provider_options][:reasoning_effort] == "high"
  end

  test "updates token preview from streaming callbacks before final usage" do
    ask_fun = fn _text, opts ->
      opts[:on_result].("streaming text")
      Process.sleep(100)

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
      Process.sleep(@late_prompt_sleep_ms)
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
                    %{type: :assistant_aborted, data: %{reason: "Cancelled."}}},
                   500

    refute_receive {Exy.Session, :event, %{type: :assistant_message_added}}, 100

    state = Exy.Session.state(server)
    assert state.status == :idle
    assert [%{role: :user}, %{role: :assistant, text: "Cancelled."}] = state.messages
    assert state.notifications == []
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
    assert state.notifications == []
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

    assert_receive {Exy.Session, :event,
                    %{type: :assistant_stream_finished, data: %{text: "done"}}},
                   500

    state = Exy.Session.state(server)
    assert [%{role: :user}, %{role: :assistant, text: "done"}] = state.messages
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
