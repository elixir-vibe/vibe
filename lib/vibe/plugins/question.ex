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
    ensure_table!()
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
    case pop_waiter(session_id) do
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
    case pop_waiter(session_id) do
      {:ok, pid} -> send(pid, {:question_cancelled})
      :error -> :ok
    end

    {:ok, state}
  end

  def handle_event(_event, _context, state), do: {:ok, state}

  @spec register_waiter(String.t(), pid()) :: :ok
  def register_waiter(session_id, pid) do
    ensure_table!()
    :ets.insert(@table, {session_id, pid})
    :ok
  end

  @spec unregister_waiter(String.t()) :: :ok
  def unregister_waiter(session_id) do
    if table?(), do: :ets.delete(@table, session_id)
    :ok
  end

  defp pop_waiter(session_id) do
    if table?() do
      case :ets.lookup(@table, session_id) do
        [{^session_id, pid}] ->
          :ets.delete(@table, session_id)
          {:ok, pid}

        [] ->
          :error
      end
    else
      :error
    end
  end

  defp ensure_table! do
    unless table?() do
      :ets.new(@table, [:named_table, :public, :set])
    end
  rescue
    ArgumentError -> :ok
  end

  defp table?, do: :ets.info(@table) != :undefined
end
