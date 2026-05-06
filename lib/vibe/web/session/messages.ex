defmodule Vibe.Web.Session.Messages do
  @moduledoc "Builds displayable session messages from UI state and final stream events."

  @spec display([map()], [map()], boolean()) :: [map()]
  def display(messages, final_assistant_messages, active_streaming?) do
    messages
    |> semantic_messages(active_streaming?)
    |> ensure_final_assistant_messages(final_assistant_messages)
    |> with_message_dom_ids()
  end

  @spec append_final_assistant([map()], map()) :: [map()]
  def append_final_assistant(messages, message) when is_map(message) do
    messages
    |> List.insert_at(-1, message)
    |> Enum.uniq_by(&Map.get(&1, :text))
  end

  defp ensure_final_assistant_messages(messages, final_assistant_messages) do
    existing_texts =
      messages
      |> Enum.filter(&(Map.get(&1, :role) == :assistant and not Map.get(&1, :streaming?, false)))
      |> Enum.map(&Map.get(&1, :text))
      |> MapSet.new()

    authoritative =
      final_assistant_messages
      |> Enum.uniq_by(&Map.get(&1, :text))
      |> Enum.reject(&MapSet.member?(existing_texts, Map.get(&1, :text)))

    messages ++ authoritative
  end

  defp with_message_dom_ids(messages) do
    messages
    |> Enum.with_index()
    |> Enum.map(fn {message, index} ->
      Map.put_new(message, :dom_id, "message-#{index}")
    end)
  end

  defp semantic_messages(messages, active_streaming?) do
    messages
    |> Enum.flat_map(fn message ->
      cond do
        empty_stream_placeholder?(message) -> []
        Map.get(message, :streaming?, false) and active_streaming? -> [message]
        Map.get(message, :streaming?, false) -> [Map.delete(message, :streaming?)]
        true -> [message]
      end
    end)
  end

  defp empty_stream_placeholder?(message) do
    Map.get(message, :streaming?, false) and String.trim(Map.get(message, :text, "")) == ""
  end
end
