defmodule Vibe.SessionTest do
  use ExUnit.Case, async: false

  alias Vibe.Files.Artifacts
  alias Vibe.UI.ToolEvent

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "vibe-session-test-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:vibe, :session_dir)
    Application.put_env(:vibe, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :session_dir, previous),
        else: Application.delete_env(:vibe, :session_dir)

      File.rm_rf(session_dir)
    end)

    Vibe.Session.Store.clear()
    {:ok, session_dir: session_dir}
  end

  test "SQLite persists trajectory and UI events" do
    session_id = "test-session"

    Vibe.Session.Store.append_trajectory(:user_message, %{prompt: "hello"},
      session_id: session_id
    )

    Vibe.Session.Store.append_trajectory(
      :llm_usage,
      %{input_tokens: 2, output_tokens: 3, total_tokens: 5},
      session_id: session_id
    )

    ui_event = Vibe.UI.Event.new(:user_message_added, session_id, %{text: "hello"})
    assert :ok = Vibe.Session.Store.append_ui_event(ui_event, 1)

    assert [%{id: ^session_id, path: path, message_count: 1, first_message: "hello"}] =
             Vibe.Session.Store.list()

    assert path == Path.expand(Vibe.Paths.database())

    assert [user, usage] = Vibe.Session.Store.events(session_id)
    assert user.type == :user_message
    assert user.data.prompt == "hello"
    assert usage.type == :llm_usage
    assert usage.data.total_tokens == 5

    assert [{1, restored_event}] = Vibe.Session.Store.ui_events(session_id)
    assert restored_event.type == :user_message_added
    assert restored_event.data.text == "hello"
  end

  test "session JSON decoding leaves unknown boundary keys as strings" do
    session_id = "codec-boundary"

    Vibe.Session.Store.append_trajectory(
      :assistant_message,
      %{result: %{"provider_specific" => "kept"}},
      session_id: session_id
    )

    assert [%{data: %{result: %{"provider_specific" => "kept"}}}] =
             Vibe.Session.Store.events(session_id)
  end

  test "restores tool UI events as tool event structs" do
    session_id = "tool-ui-event-#{System.unique_integer([:positive])}"

    assert :ok =
             Vibe.Session.Store.append_ui_event(
               Vibe.UI.Event.new(
                 :tool_started,
                 session_id,
                 Vibe.UI.ToolEvent.started(id: "tool-1", name: :eval, args: %{code: "1 + 1"})
               ),
               1
             )

    assert [{1, %{type: :tool_started, data: %ToolEvent{} = event}}] =
             Vibe.Session.Store.ui_events(session_id)

    assert event.id == "tool-1"
    assert event.name == :eval
    assert event.status == :running
  end

  test "trajectory-only sessions project basic visible history" do
    session_id = "trajectory-only"

    Vibe.Session.Store.append_trajectory(:user_message, %{prompt: "old hello"},
      session_id: session_id
    )

    Vibe.Session.Store.append_trajectory(:assistant_message, %{result: "old response"},
      session_id: session_id
    )

    assert [%{id: ^session_id, message_count: 2, first_message: "old hello"}] =
             Vibe.Session.Store.list()

    assert [{1, user}, {2, assistant}] = Vibe.Session.Store.ui_events(session_id)
    assert user.type == :user_message_added
    assert user.data.text == "old hello"
    assert assistant.type == :assistant_message_added
    assert assistant.data.result == "old response"
  end

  test "prompt runner receives fenced memory context while visible user message stays clean" do
    memory_dir =
      Path.join(
        System.tmp_dir!(),
        "vibe-memory-session-test-#{System.unique_integer([:positive])}"
      )

    previous = Application.get_env(:vibe, :memory_dir)
    Application.put_env(:vibe, :memory_dir, memory_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:vibe, :memory_dir, previous),
        else: Application.delete_env(:vibe, :memory_dir)

      File.rm_rf(memory_dir)
    end)

    assert {:ok, _entry} = Vibe.Memory.add(:global, "Washington weather source is weather.gov")
    skills_dir = Path.join([memory_dir, "skills", "weather-source"])
    File.mkdir_p!(skills_dir)

    previous_home = Application.get_env(:vibe, :home_dir)
    Application.put_env(:vibe, :home_dir, memory_dir)

    on_exit(fn ->
      if previous_home,
        do: Application.put_env(:vibe, :home_dir, previous_home),
        else: Application.delete_env(:vibe, :home_dir)
    end)

    File.write!(Path.join(skills_dir, "SKILL.md"), """
    ---
    name: weather-source
    description: Use authoritative weather sources
    triggers:
      - weather.gov
    ---
    # Weather Source

    Prefer authoritative weather sources when answering weather questions.
    """)

    parent = self()

    {:ok, server} =
      Vibe.Session.start_link(
        session_id: "memory-context-session",
        ask_fun: fn text, _opts ->
          send(parent, {:asked, text})
          {:ok, "ok"}
        end
      )

    assert :ok = Vibe.Session.dispatch(server, {:submit_prompt, %{text: "weather.gov"}})
    assert_receive {:asked, text}
    assert text =~ "<memory-context>"
    assert text =~ "Washington weather source is weather.gov"
    assert text =~ "## Active skills"
    assert text =~ "### weather-source"
    assert text =~ "Prefer authoritative weather sources"

    Process.sleep(20)
    assert [%{text: "weather.gov"} | _] = Vibe.Session.state(server).messages
  end

  test "delete removes session artifact directory" do
    session_id = "delete-artifacts"
    artifact_dir = Artifacts.session_artifact_dir(session_id)
    File.mkdir_p!(artifact_dir)
    File.write!(Path.join(artifact_dir, "image.png"), "png")

    Vibe.Session.Store.append_trajectory(:user_message, %{prompt: "hello"},
      session_id: session_id
    )

    assert File.exists?(artifact_dir)
    assert :ok = Vibe.Session.Store.delete(session_id)
    refute File.exists?(artifact_dir)
  end

  test "invalid persisted atoms and event types are skipped without creating atoms" do
    session_id = "crafted"

    File.mkdir_p!(Vibe.Session.Store.dir())

    File.write!(
      Vibe.Session.Store.path(session_id),
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

    assert [] = Vibe.Session.Store.ui_events(session_id)
  end
end
