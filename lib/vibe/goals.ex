defmodule Vibe.Goals do
  @moduledoc "Persisted long-running session goals and model-facing goal helpers."

  import Ecto.Query

  alias Vibe.Goals.Goal
  alias Vibe.Repo
  alias Vibe.Storage.Schema.Goal, as: GoalRow

  @max_objective_chars 8_000

  @spec get(String.t() | nil) :: Goal.t() | nil
  def get(session_id \\ Vibe.Command.Streaming.current_session_id())
  def get(nil), do: nil

  def get(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()

    case Repo.get(GoalRow, session_id) do
      %GoalRow{} = row -> from_row(row)
      nil -> nil
    end
  end

  @spec set(String.t(), String.t(), keyword()) :: {:ok, Goal.t()} | {:error, term()}
  def set(session_id, objective, opts \\ [])
      when is_binary(session_id) and is_binary(objective) do
    with {:ok, objective} <- validate_objective(objective),
         {:ok, token_budget} <- validate_budget(Keyword.get(opts, :token_budget)),
         {:ok, status} <- Goal.status(Keyword.get(opts, :status, :active)) do
      Vibe.Storage.ensure!()
      now = now()
      existing = Repo.get(GoalRow, session_id)

      row = %{
        session_id: session_id,
        goal_id: goal_id(existing),
        objective: objective,
        status: Atom.to_string(status),
        token_budget: token_budget,
        tokens_used: (existing && existing.tokens_used) || 0,
        time_used_seconds: (existing && existing.time_used_seconds) || 0,
        created_at: (existing && existing.created_at) || now,
        updated_at: now
      }

      %GoalRow{}
      |> Map.merge(row)
      |> Repo.insert(
        on_conflict: [
          set: [
            goal_id: row.goal_id,
            objective: row.objective,
            status: row.status,
            token_budget: row.token_budget,
            updated_at: row.updated_at
          ]
        ],
        conflict_target: :session_id
      )
      |> case do
        {:ok, _row} -> {:ok, get(session_id)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @spec update_status(String.t() | nil, Goal.status() | String.t()) ::
          {:ok, Goal.t()} | {:error, term()}
  def update_status(session_id \\ Vibe.Command.Streaming.current_session_id(), status)
  def update_status(nil, _status), do: {:error, :missing_session_id}

  def update_status(session_id, status) when is_binary(session_id) do
    with {:ok, status} <- Goal.status(status),
         %GoalRow{} = row <- row(session_id) do
      updated_at = now()

      row
      |> Ecto.Changeset.change(status: Atom.to_string(status), updated_at: updated_at)
      |> Repo.update()
      |> case do
        {:ok, _row} -> {:ok, get(session_id)}
        {:error, reason} -> {:error, reason}
      end
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec complete(String.t() | nil) :: {:ok, Goal.t()} | {:error, term()}
  def complete(session_id \\ Vibe.Command.Streaming.current_session_id()),
    do: update_status(session_id, :complete)

  @spec blocked(String.t() | nil) :: {:ok, Goal.t()} | {:error, term()}
  def blocked(session_id \\ Vibe.Command.Streaming.current_session_id()),
    do: update_status(session_id, :blocked)

  @spec pause(String.t() | nil) :: {:ok, Goal.t()} | {:error, term()}
  def pause(session_id \\ Vibe.Command.Streaming.current_session_id()),
    do: update_status(session_id, :paused)

  @spec resume(String.t() | nil) :: {:ok, Goal.t()} | {:error, term()}
  def resume(session_id \\ Vibe.Command.Streaming.current_session_id()),
    do: update_status(session_id, :active)

  @spec clear(String.t() | nil) :: :ok | {:error, term()}
  def clear(session_id \\ Vibe.Command.Streaming.current_session_id())
  def clear(nil), do: {:error, :missing_session_id}

  def clear(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()
    Repo.delete_all(from(goal in GoalRow, where: goal.session_id == ^session_id))
    :ok
  end

  @spec context_block(String.t()) :: String.t()
  def context_block(session_id) when is_binary(session_id) do
    case get(session_id) do
      %Goal{status: :active} = goal -> render_context(goal)
      _goal -> ""
    end
  end

  @spec summary(Goal.t() | nil) :: String.t()
  def summary(nil), do: "No goal is currently set."

  def summary(%Goal{} = goal) do
    [
      "Goal #{String.replace(Atom.to_string(goal.status), "_", " ")}",
      "Objective: #{goal.objective}",
      usage_summary(goal)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n")
  end

  @spec validate_objective(String.t()) :: {:ok, String.t()} | {:error, term()}
  def validate_objective(objective) when is_binary(objective) do
    objective = String.trim(objective)

    cond do
      objective == "" ->
        {:error, :empty_objective}

      String.length(objective) > @max_objective_chars ->
        {:error, {:objective_too_long, String.length(objective), @max_objective_chars}}

      true ->
        {:ok, objective}
    end
  end

  defp row(session_id) do
    Vibe.Storage.ensure!()
    Repo.get(GoalRow, session_id)
  end

  defp validate_budget(nil), do: {:ok, nil}
  defp validate_budget(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp validate_budget(value), do: {:error, {:invalid_token_budget, value}}

  defp render_context(%Goal{} = goal) do
    template = Vibe.Prompts.goal_continuation()

    template
    |> String.replace("{{ objective }}", goal.objective)
    |> String.replace("{{ tokens_used }}", Integer.to_string(goal.tokens_used))
    |> String.replace("{{ token_budget }}", budget_text(goal.token_budget))
    |> String.replace("{{ remaining_tokens }}", remaining_text(goal))
    |> then(&"<goal_context>\n#{&1}\n</goal_context>")
  end

  defp from_row(%GoalRow{} = row) do
    {:ok, status} = Goal.status(row.status)

    %Goal{
      session_id: row.session_id,
      goal_id: row.goal_id,
      objective: row.objective,
      status: status,
      token_budget: row.token_budget,
      tokens_used: row.tokens_used || 0,
      time_used_seconds: row.time_used_seconds || 0,
      created_at: row.created_at,
      updated_at: row.updated_at
    }
  end

  defp goal_id(%GoalRow{goal_id: goal_id}), do: goal_id

  defp goal_id(_row),
    do: "goal-" <> Base.url_encode64(:crypto.strong_rand_bytes(9), padding: false)

  defp budget_text(nil), do: "not set"
  defp budget_text(value), do: Integer.to_string(value)

  defp remaining_text(%Goal{token_budget: nil}), do: "not set"

  defp remaining_text(%Goal{token_budget: budget, tokens_used: used}),
    do: Integer.to_string(max(budget - used, 0))

  defp usage_summary(%Goal{token_budget: nil, time_used_seconds: 0}), do: ""

  defp usage_summary(%Goal{} = goal) do
    parts = []

    parts =
      if goal.time_used_seconds > 0, do: ["time #{goal.time_used_seconds}s" | parts], else: parts

    parts =
      if goal.token_budget do
        ["tokens #{goal.tokens_used}/#{goal.token_budget}" | parts]
      else
        parts
      end

    Enum.reverse(parts) |> Enum.join(" · ")
  end

  defp now, do: DateTime.utc_now() |> Vibe.Storage.normalize_datetime()
end
