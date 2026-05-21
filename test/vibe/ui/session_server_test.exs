defmodule Vibe.SessionProcessTest do
  use ExUnit.Case, async: true

  @late_prompt_sleep_ms 5_000

  test "dispatches commands, emits events, and records usage" do
    ask_fun = fn _text, _opts ->
      {:ok, %{model: "test-model", usage: %{input_tokens: 4, output_tokens: 6, total_tokens: 10}}}
    end

    {:ok, server} =
      Vibe.Session.start_link(persist?: false, session_id: "ui-session", ask_fun: ask_fun)

    :ok = Vibe.Session.subscribe(server)
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Vibe.Session, :event, %{type: :user_message_added}}, 500
    assert_receive {Vibe.Session, :event, %{type: :assistant_message_added}}, 500
    assert_receive {Vibe.Session, :event, %{type: :usage_updated}}, 500

    state = Vibe.Session.state(server)
    assert Enum.map(state.messages, & &1.role) == [:user, :assistant]
    assert state.usage.total_tokens == 10
  end

  test "semantic prompt content is preserved in UI events" do
    prompt = [
      Vibe.Model.Content.text("describe"),
      Vibe.Model.Content.image(data: Base.encode64(<<1, 2, 3>>), mime_type: "image/png")
    ]

    {:ok, server} =
      Vibe.Session.start_link(
        persist?: false,
        session_id: "semantic-content-session",
        ask_fun: fn text, _opts -> {:ok, text} end
      )

    :ok = Vibe.Session.subscribe(server)
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{content: prompt}})

    assert_receive {Vibe.Session, :event,
                    %{type: :user_message_added, data: %{content: ^prompt, image_count: 1}}},
                   500

    assert [%{role: :user, content: ^prompt, image_count: 1} | _] =
             Vibe.Session.state(server).messages
  end

  test "restores snapshot from durable UI events" do
    session_id = "restore-session-#{System.unique_integer([:positive])}"
    path = Vibe.Session.Store.ui_events_path(session_id)
    on_exit(fn -> File.rm(path) end)

    {:ok, server} =
      Vibe.Session.start_link(session_id: session_id, ask_fun: fn _text, _opts -> {:ok, "ok"} end)

    :ok = Vibe.Session.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    GenServer.stop(server)

    {:ok, restored} =
      Vibe.Session.start_link(session_id: session_id, ask_fun: fn _text, _opts -> {:ok, "ok"} end)

    assert [%{kind: :model_selector}] = Vibe.Session.state(restored).overlays
    GenServer.stop(restored)
  end

  test "attach can replay missed events from durable log before in-memory tail" do
    session_id = "durable-replay-#{System.unique_integer([:positive])}"
    path = Vibe.Session.Store.path(session_id)
    on_exit(fn -> File.rm(path) end)

    events =
      for index <- 1..201 do
        {index, Vibe.Event.new(:overlay_opened, session_id, %{id: index, kind: :test_overlay})}
      end

    :ok = Vibe.Session.Store.append_ui_events(events)

    {:ok, server} =
      Vibe.Session.start_link(session_id: session_id, ask_fun: fn _text, _opts -> {:ok, "ok"} end)

    {:ok, _snapshot, 201} = Vibe.Session.attach(server, self(), after: 1)
    assert_receive {Vibe.Session, :event, %{data: %{id: 2}}}
    assert_receive {Vibe.Session, :event, %{data: %{id: 3}}}
    GenServer.stop(server)
  end

  test "attach returns snapshot cursor and replays missed tail events" do
    {:ok, server} =
      Vibe.Session.start_link(
        persist?: false,
        session_id: "attach-session",
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Vibe.Session.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    {:ok, snapshot, cursor} = Vibe.Session.attach(server)

    assert [%{kind: :model_selector}] = snapshot.overlays
    assert cursor == 1

    :ok = Vibe.Session.dispatch(server, {:close_overlay, %{}})
    assert_receive {Vibe.Session, :event, %{type: :overlay_closed}}, 500

    {:ok, snapshot, cursor} = Vibe.Session.attach(server, self(), after: 1)
    assert snapshot.overlays == []
    assert cursor == 2
    assert_receive {Vibe.Session, :event, %{type: :overlay_closed}}, 500
  end

  test "default agent ask options preserve streaming callbacks" do
    on_result = fn _text -> :ok end
    on_thinking = fn _text -> :ok end

    opts =
      Vibe.Session.agent_ask_opts(
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
      Vibe.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        model: "openai_codex:gpt-5.5",
        effort: :medium,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Vibe.Session.dispatch(server, {:cycle_model, %{direction: :forward}})
    :ok = Vibe.Session.dispatch(server, :cycle_effort)

    state = Vibe.Session.state(server)
    assert state.model != "openai_codex:gpt-5.5"
    assert state.effort == :high
  end

  test "opens model and effort selectors through session commands" do
    {:ok, server} =
      Vibe.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        model: "openai_codex:gpt-5.5",
        effort: :medium,
        ask_fun: fn _text, _opts -> {:ok, "ok"} end
      )

    :ok = Vibe.Session.dispatch(server, :open_model_selector)
    assert Vibe.Session.state(server).selector.kind == :model_selector

    :ok = Vibe.Session.dispatch(server, :open_effort_selector)
    state = Vibe.Session.state(server)
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
      Vibe.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        model: "model-a",
        effort: :medium,
        ask_fun: ask_fun
      )

    :ok = Vibe.Session.dispatch(server, {:model_selected, %{model: "model-b"}})
    :ok = Vibe.Session.dispatch(server, {:effort_selected, %{effort: :high}})
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {:ask_opts, opts}, 500
    assert opts[:model] == "model-b"
    assert opts[:effort] == :high
    assert opts[:llm_opts][:provider_options][:reasoning_effort] == "high"
  end

  test "updates token preview from streaming callbacks before final usage" do
    parent = self()

    ask_fun = fn _text, opts ->
      opts[:on_result].("streaming text")
      send(parent, {:streaming_preview_sent, self()})

      receive do
        :finish_streaming_preview ->
          {:ok,
           %{
             output: "streaming text",
             usage: %{input_tokens: 10, output_tokens: 20, total_tokens: 30}
           }}
      after
        1_000 ->
          {:error, :streaming_preview_timeout}
      end
    end

    {:ok, server} =
      Vibe.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Vibe.Session.subscribe(server)
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Vibe.Session, :event, %{type: :assistant_delta}}, 500
    assert_receive {:streaming_preview_sent, ask_pid}, 500

    preview_state = Vibe.Session.state(server)
    assert preview_state.usage.total_tokens == 0
    assert preview_state.usage_preview.total_tokens > 0
    assert Vibe.UI.ViewModel.from_state(preview_state).footer.usage.total_tokens > 0

    send(ask_pid, :finish_streaming_preview)
    assert_receive {Vibe.Session, :event, %{type: :usage_updated}}, 500

    final_state = Vibe.Session.state(server)
    assert final_state.usage.total_tokens == 30
    assert final_state.usage_preview.total_tokens == 0
    assert Vibe.UI.ViewModel.from_state(final_state).footer.usage.total_tokens == 30
  end

  test "cancel aborts active prompt task and ignores late results" do
    ask_fun = fn _text, _opts ->
      Process.sleep(@late_prompt_sleep_ms)
      {:ok, "too late"}
    end

    {:ok, server} =
      Vibe.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Vibe.Session.subscribe(server)
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Vibe.Session, :event, %{type: :assistant_stream_started}}, 500
    :ok = Vibe.Session.dispatch(server, :cancel_stream)

    assert_receive {Vibe.Session, :event,
                    %{type: :assistant_aborted, data: %{reason: "Cancelled."}}},
                   500

    refute_receive {Vibe.Session, :event, %{type: :assistant_message_added}}, 100

    state = Vibe.Session.state(server)
    assert state.status == :idle
    assert [%{role: :user}, %{role: :assistant, text: "Cancelled."}] = state.messages
    assert state.notifications == []
  end

  test "records ask function crashes as assistant errors" do
    ask_fun = fn _text, _opts -> raise ArgumentError, "boom" end

    {:ok, server} =
      Vibe.Session.start_link(persist?: false, session_id: "ui-session", ask_fun: ask_fun)

    :ok = Vibe.Session.subscribe(server)
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Vibe.Session, :event, %{type: :assistant_aborted}}, 500
    assert_receive {Vibe.Session, :event, %{type: :assistant_message_added}}, 500

    state = Vibe.Session.state(server)
    assert [%{role: :user}, %{role: :assistant, error: error}] = state.messages
    assert state.notifications == []
    assert error.message == "ArgumentError: boom"
    assert error.detail =~ "ArgumentError"
    assert error.detail =~ "boom"
  end

  test "non-streaming ask functions still replace loader with final response" do
    ask_fun = fn _text, _opts -> {:ok, "done"} end

    {:ok, server} =
      Vibe.Session.start_link(
        persist?: false,
        session_id: "ui-session",
        ask_fun: ask_fun,
        streaming?: true
      )

    :ok = Vibe.Session.subscribe(server)
    :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "hello"}})

    assert_receive {Vibe.Session, :event, %{type: :assistant_stream_started}}, 500

    assert_receive {Vibe.Session, :event,
                    %{type: :assistant_stream_finished, data: %{text: "done"}}},
                   500

    state = Vibe.Session.state(server)
    assert [%{role: :user}, %{role: :assistant, text: "done"}] = state.messages
    assert is_nil(state.streaming_message)
  end

  test "supports overlay commands" do
    {:ok, server} = Vibe.Session.start_link(persist?: false, session_id: "ui-session")

    :ok = Vibe.Session.dispatch(server, {:open_overlay, %{kind: :model_selector}})
    assert [%{kind: :model_selector}] = Vibe.Session.state(server).overlays

    :ok = Vibe.Session.dispatch(server, :close_overlay)
    assert [] = Vibe.Session.state(server).overlays
  end
end
