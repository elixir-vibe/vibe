defmodule Vibe.Memory.BuiltinProvider do
  @moduledoc "Default memory provider backed by SQLite storage."
  use Vibe.Memory.Provider

  @subagent_result_preview_chars 2_000

  @impl true
  def system_prompt_block(_state) do
    blocks =
      [user: Vibe.Memory.list(:user), global: Vibe.Memory.list(:global)]
      |> Enum.flat_map(fn {scope, entries} ->
        case entries do
          [] ->
            []

          entries ->
            [
              [
                to_string(scope),
                " memory:\n",
                entries |> Enum.map(&["- ", &1.text]) |> Enum.intersperse("\n")
              ]
            ]
        end
      end)

    blocks |> Enum.intersperse("\n\n") |> IO.iodata_to_binary()
  end

  @impl true
  def prefetch(query, context, _state) do
    scopes = scopes(context)

    if Enum.any?(scopes, &(Vibe.Memory.list(&1) != [])) do
      Vibe.Memory.context_block(query, scopes: scopes, limit: 8)
    else
      ""
    end
  end

  @impl true
  def on_delegation(task, result, context, _state) do
    with parent_session_id when is_binary(parent_session_id) <-
           Map.get(context, :parent_session_id),
         true <- byte_size(result) > 0 do
      text =
        "Subagent completed: #{task}\nResult: #{String.slice(result, 0, @subagent_result_preview_chars)}"

      _ = Vibe.Memory.add({:session, parent_session_id}, text)
    end

    :ok
  end

  defp scopes(context) do
    scopes = [:global, :user]

    case Map.get(context, :session_id) do
      session_id when is_binary(session_id) -> Enum.reverse([{:session, session_id} | scopes])
      _session_id -> Enum.reverse(scopes)
    end
  end
end
