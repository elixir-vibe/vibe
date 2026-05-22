defmodule Vibe.UI.SlashCommands.Goal do
  @moduledoc "Slash command: /goal — set, view, pause, resume, or clear a long-running goal."
  @behaviour Vibe.UI.SlashCommands.Command

  alias Vibe.Event
  alias Vibe.UI.SlashCommands.Spec

  @impl true
  def spec do
    %Spec{
      name: "goal",
      description: "Set or view the goal for a long-running task"
    }
  end

  @impl true
  def run(args, session_state) do
    args = String.trim(args || "")

    case String.downcase(args) do
      "" -> show_goal(session_state)
      "clear" -> {:command, :clear_goal}
      "pause" -> {:command, {:update_goal_status, %{status: :paused}}}
      "resume" -> {:command, {:update_goal_status, %{status: :active}}}
      "complete" -> {:command, {:update_goal_status, %{status: :complete}}}
      "blocked" -> {:command, {:update_goal_status, %{status: :blocked}}}
      _objective -> set_goal(args, session_state)
    end
  end

  defp show_goal(session_state) do
    goal = session_state.goal || Vibe.Goals.get(session_state.session_id)

    {:events,
     [
       Event.new(:notification_added, session_state.session_id, %{
         level: :info,
         text: Vibe.Goals.summary(goal),
         ttl_ms: 10_000
       })
     ]}
  end

  defp set_goal(objective, session_state) do
    case Vibe.Goals.validate_objective(objective) do
      {:ok, objective} ->
        {:command, {:set_goal, %{objective: objective}}}

      {:error, :empty_objective} ->
        notice(:warning, "Usage: /goal <objective>", session_state.session_id)

      {:error, {:objective_too_long, actual, max}} ->
        notice(
          :warning,
          "Goal is too long: #{actual}/#{max} characters",
          session_state.session_id
        )
    end
  end

  defp notice(level, text, session_id) do
    {:events, [Event.new(:notification_added, session_id, %{level: level, text: text})]}
  end
end
