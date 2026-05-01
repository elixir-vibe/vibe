defmodule Exy.Memory.BuiltinProvider do
  @moduledoc "Internal implementation module."
  use Exy.Memory.Provider

  @subagent_result_preview_chars 2_000

  @impl true
  def system_prompt_block(_state) do
    blocks =
      [user: Exy.Memory.list(:user), global: Exy.Memory.list(:global)]
      |> Enum.flat_map(fn {scope, entries} ->
        case entries do
          [] -> []
          entries -> ["#{scope} memory:\n" <> Enum.map_join(entries, "\n", &"- #{&1.text}")]
        end
      end)

    Enum.join(blocks, "\n\n")
  end

  @impl true
  def prefetch(query, context, _state) do
    scopes = scopes(context)
    Exy.Memory.context_block(query, scopes: scopes, limit: 8)
  end

  @impl true
  def on_delegation(task, result, context, _state) do
    with parent_session_id when is_binary(parent_session_id) <-
           Map.get(context, :parent_session_id),
         true <- byte_size(result) > 0 do
      text =
        "Subagent completed: #{task}\nResult: #{String.slice(result, 0, @subagent_result_preview_chars)}"

      _ = Exy.Memory.add({:session, parent_session_id}, text)
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
