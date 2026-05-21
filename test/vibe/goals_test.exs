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
