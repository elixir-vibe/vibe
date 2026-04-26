defmodule Exy.Subagents.JobTest do
  use ExUnit.Case, async: false

  setup do
    session_dir =
      Path.join(System.tmp_dir!(), "exy-subagent-job-#{System.unique_integer([:positive])}")

    previous = Application.get_env(:exy, :session_dir)
    Application.put_env(:exy, :session_dir, session_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:exy, :session_dir, previous),
        else: Application.delete_env(:exy, :session_dir)

      File.rm_rf(session_dir)
    end)

    {:ok, session_dir: session_dir}
  end

  test "starts supervised LLM subagent with attachable child session" do
    parent_session_id = "parent-session"

    assert {:ok, job} =
             Exy.Subagents.start("hello subagent",
               role: :scout,
               parent_session_id: parent_session_id,
               ask_fun: fn text, _opts -> {:ok, "child saw: #{text}"} end
             )

    assert job.status == :running
    assert is_binary(job.child_session_id)

    assert {:ok, finished} = Exy.Subagents.await(job.id, 2_000)
    assert finished.status == :ok
    assert finished.result == "child saw: hello subagent"

    assert {:ok, child_session} = Exy.Session.lookup(job.child_session_id)
    state = Exy.Session.state(child_session)
    assert Enum.any?(state.messages, &(&1[:text] == "hello subagent"))
    assert Enum.any?(state.messages, &(&1[:result] == "child saw: hello subagent"))

    parent_events = Exy.Session.Store.events(parent_session_id)
    assert Enum.any?(parent_events, &(&1.type == :subagent_started))
    assert Enum.any?(parent_events, &(&1.type == :subagent_finished))
  end

  test "running subagent child session is read-only for other callers" do
    assert {:ok, job} =
             Exy.Subagents.start("locked task",
               role: :scout,
               ask_fun: fn _text, _opts ->
                 Process.sleep(150)
                 {:ok, "done"}
               end
             )

    assert {:ok, child_session} = wait_for_child_session(job.child_session_id)
    :ok = Exy.Session.dispatch(child_session, {:submit_prompt, %{text: "interrupt"}})
    state = Exy.Session.state(child_session)

    assert Enum.any?(state.notifications, fn notification ->
             String.contains?(notification.text, "read-only")
           end)

    assert {:ok, _finished} = Exy.Subagents.await(job.id, 2_000)
  end

  test "unknown roles fail unless explicit model or system is provided" do
    assert {:error, {:unknown_role, :missing_role}} =
             Exy.Subagents.start("task", role: :missing_role)

    assert {:ok, job} =
             Exy.Subagents.start("task",
               role: :missing_role,
               model: "openai_codex:gpt-5.5",
               ask_fun: fn _text, _opts -> {:ok, "ok"} end
             )

    assert {:ok, _finished} = Exy.Subagents.await(job.id, 2_000)
  end

  test "synchronous ask uses the same job path" do
    assert {:ok, "answer: question"} =
             Exy.Subagents.ask("question",
               ask_fun: fn text, _opts -> {:ok, "answer: #{text}"} end,
               timeout: 2_000
             )
  end

  defp wait_for_child_session(session_id, attempts \\ 20)

  defp wait_for_child_session(session_id, attempts) when attempts > 0 do
    case Exy.Session.lookup(session_id) do
      {:ok, session} ->
        {:ok, session}

      {:error, :not_found} ->
        Process.sleep(10)
        wait_for_child_session(session_id, attempts - 1)
    end
  end

  defp wait_for_child_session(_session_id, 0), do: {:error, :not_found}
end
