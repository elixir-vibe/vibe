defmodule Vibe.Plugins.Question do
  @moduledoc """
  Plugin: interactive question tool for the agent.

  Provides a `question` model-facing action that pauses execution, shows
  options to the user via a selector overlay, and returns the chosen answer.

  The plugin tracks which process is waiting for an answer per session and
  dispatches the reply when it sees a `:selector_confirmed` event with
  `selector: :question_selector`.
  """
  use Vibe.Plugin

  @table :vibe_question_waiters

  @impl true
  def init(_opts) do
    Vibe.Plugin.Waiters.ensure_table!(@table)
    {:ok, %{}}
  end

  @impl true
  def actions(_state), do: [Vibe.Plugins.Question.Action]

  @impl true
  def handle_event(
        %{type: :selector_confirmed, data: %{selector: :question_selector, item: answer}},
        %{session_id: session_id},
        state
      ) do
    case Vibe.Plugin.Waiters.pop(@table, session_id) do
      {:ok, pid} -> send(pid, {:question_answered, answer})
      :error -> :ok
    end

    {:ok, state}
  end

  def handle_event(
        %{type: :selector_closed},
        %{session_id: session_id},
        state
      ) do
    case Vibe.Plugin.Waiters.pop(@table, session_id) do
      {:ok, pid} -> send(pid, {:question_cancelled})
      :error -> :ok
    end

    {:ok, state}
  end

  def handle_event(_event, _context, state), do: {:ok, state}

  @spec register_waiter(String.t(), pid()) :: :ok
  def register_waiter(session_id, pid), do: Vibe.Plugin.Waiters.register(@table, session_id, pid)

  @spec unregister_waiter(String.t()) :: :ok
  def unregister_waiter(session_id), do: Vibe.Plugin.Waiters.unregister(@table, session_id)
end
