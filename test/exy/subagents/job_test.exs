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

  test "synchronous ask uses the same job path" do
    assert {:ok, "answer: question"} =
             Exy.Subagents.ask("question",
               ask_fun: fn text, _opts -> {:ok, "answer: #{text}"} end,
               timeout: 2_000
             )
  end
end
