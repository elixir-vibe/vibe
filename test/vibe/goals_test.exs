defmodule Vibe.GoalsTest do
  use ExUnit.Case, async: false

  setup do
    Vibe.Session.Store.clear()
    :ok
  end

  test "sets, updates, summarizes, and clears a session goal" do
    assert {:ok, goal} = Vibe.Goals.set("goal-session", "Ship a focused feature")
    assert goal.status == :active
    assert goal.objective == "Ship a focused feature"

    assert Vibe.Goals.summary(goal) =~ "Objective: Ship a focused feature"
    assert Vibe.Goals.context_block("goal-session") =~ "<goal_context>"
    assert Vibe.Goals.context_block("goal-session") =~ "Ship a focused feature"

    assert {:ok, paused} = Vibe.Goals.update_status("goal-session", :paused)
    assert paused.status == :paused
    assert Vibe.Goals.context_block("goal-session") == ""

    assert :ok = Vibe.Goals.clear("goal-session")
    assert Vibe.Goals.get("goal-session") == nil
  end

  test "active goal is injected into the next prompt" do
    parent = self()
    assert {:ok, _goal} = Vibe.Goals.set("prompt-goal", "Keep working until the docs are done")

    {:ok, session} =
      Vibe.Session.start_link(
        session_id: "prompt-goal",
        persist?: true,
        ask_fun: fn prompt, _opts ->
          send(parent, {:prompt, prompt})
          "ok"
        end
      )

    assert :ok = Vibe.Session.dispatch(session, {:submit_prompt, %{text: "Start"}})
    assert_receive {:prompt, prompt}, 1_000
    assert prompt =~ "<goal_context>"
    assert prompt =~ "Keep working until the docs are done"
  end

  test "active goals can continue after idle turns" do
    parent = self()
    session_id = "continuing-goal-#{System.unique_integer([:positive])}"
    assert {:ok, _goal} = Vibe.Goals.set(session_id, "Finish the queued work")

    ask_fun = fn prompt, _opts ->
      send(parent, {:prompt, prompt})

      if String.starts_with?(prompt, "Continue the active goal.") do
        assert {:ok, _goal} = Vibe.Goals.complete(session_id)
      end

      {:ok, "ok"}
    end

    {:ok, session} =
      Vibe.Session.start_link(
        session_id: session_id,
        persist?: true,
        goal_continuation?: true,
        ask_fun: ask_fun
      )

    assert :ok = Vibe.Session.dispatch(session, {:submit_prompt, %{text: "Start"}})
    assert_receive {:prompt, "Start" <> _context}, 1_000
    assert_receive {:prompt, "Continue the active goal." <> _context}, 5_000
    assert_goal_status(session_id, :complete)
  end

  defp assert_goal_status(
         session_id,
         status,
         deadline \\ System.monotonic_time(:millisecond) + 1_000
       ) do
    if Vibe.Goals.get(session_id).status == status do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(10)
        assert_goal_status(session_id, status, deadline)
      else
        assert Vibe.Goals.get(session_id).status == status
      end
    end
  end

  test "slash command stores goal through session events" do
    {:ok, session} =
      Vibe.Session.start_link(
        session_id: "slash-goal",
        persist?: true,
        ask_fun: fn _, _ -> "ok" end
      )

    assert :ok =
             Vibe.Session.dispatch(
               session,
               {:slash_command_submitted, %{command: "goal", args: "Finish the release"}}
             )

    state = Vibe.Session.state(session)
    assert state.goal.objective == "Finish the release"
    assert Vibe.Goals.get("slash-goal").objective == "Finish the release"

    assert :ok =
             Vibe.Session.dispatch(
               session,
               {:slash_command_submitted, %{command: "goal", args: "pause"}}
             )

    assert Vibe.Session.state(session).goal.status == :paused

    assert :ok =
             Vibe.Session.dispatch(
               session,
               {:slash_command_submitted, %{command: "goal", args: "clear"}}
             )

    assert Vibe.Session.state(session).goal == nil
  end
end
