defmodule Exy.SessionTest do
  use ExUnit.Case, async: false

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-session-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    Exy.Session.Store.clear()
    {:ok, session_dir: session_dir}
  end

  test "SQLite persists trajectory and UI events" do
    session_id = "test-session"
    Exy.Session.Store.append_trajectory(:user_message, %{prompt: "hello"}, session_id: session_id)

    Exy.Session.Store.append_trajectory(
      :llm_usage,
      %{input_tokens: 2, output_tokens: 3, total_tokens: 5},
      session_id: session_id
    )

    ui_event = Exy.UI.Event.new(:user_message_added, session_id, %{text: "hello"})
    assert :ok = Exy.Session.Store.append_ui_event(ui_event, 1)

    assert [%{id: ^session_id, path: path, message_count: 1, first_message: "hello"}] =
             Exy.Session.Store.list()

    assert path == Path.expand(Exy.Paths.database())

    assert [user, usage] = Exy.Session.Store.events(session_id)
    assert user.type == :user_message
    assert user.data.prompt == "hello"
    assert usage.type == :llm_usage
    assert usage.data.total_tokens == 5

    assert [{1, restored_event}] = Exy.Session.Store.ui_events(session_id)
    assert restored_event.type == :user_message_added
    assert restored_event.data.text == "hello"
  end

  test "trajectory-only sessions project basic visible history" do
    session_id = "trajectory-only"

    Exy.Session.Store.append_trajectory(:user_message, %{prompt: "old hello"},
      session_id: session_id
    )

    Exy.Session.Store.append_trajectory(:assistant_message, %{result: "old response"},
      session_id: session_id
    )

    assert [%{id: ^session_id, message_count: 2, first_message: "old hello"}] =
             Exy.Session.Store.list()

    assert [{1, user}, {2, assistant}] = Exy.Session.Store.ui_events(session_id)
    assert user.type == :user_message_added
    assert user.data.text == "old hello"
    assert assistant.type == :assistant_message_added
    assert assistant.data.result == "old response"
  end

  test "prompt runner receives fenced memory context while visible user message stays clean" do
    memory_dir =
      Path.join(
        System.tmp_dir!(),
        "exy-memory-session-test-#{System.unique_integer([:positive])}"
      )

    previous = Application.get_env(:exy, :memory_dir)
    Application.put_env(:exy, :memory_dir, memory_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :memory_dir, previous),
        else: Application.delete_env(:exy, :memory_dir)

      File.rm_rf(memory_dir)
    end)

    assert {:ok, _entry} = Exy.Memory.add(:global, "Washington weather source is weather.gov")
    parent = self()

    {:ok, server} =
      Exy.Session.start_link(
        session_id: "memory-context-session",
        ask_fun: fn text, _opts ->
          send(parent, {:asked, text})
          {:ok, "ok"}
        end
      )

    assert :ok = Exy.Session.dispatch(server, {:submit_prompt, %{text: "weather.gov"}})
    assert_receive {:asked, text}
    assert text =~ "<memory-context>"
    assert text =~ "Washington weather source is weather.gov"

    Process.sleep(20)
    assert [%{text: "weather.gov"} | _] = Exy.Session.state(server).messages
  end

  test "invalid persisted atoms and event types are skipped without creating atoms" do
    session_id = "crafted"

    File.mkdir_p!(Exy.Session.Store.dir())

    File.write!(
      Exy.Session.Store.path(session_id),
      Jason.encode!(%{
        "entry_type" => "ui_event",
        "seq" => 1,
        "id" => "bad",
        "session_id" => session_id,
        "type" => "does_not_exist_#{System.unique_integer([:positive])}",
        "at" => DateTime.to_iso8601(DateTime.utc_now()),
        "data" => %{
          "new_atom_key_#{System.unique_integer([:positive])}" => %{"$atom" => "also_new"}
        }
      }) <> "\n"
    )

    assert [] = Exy.Session.Store.ui_events(session_id)
  end
end
