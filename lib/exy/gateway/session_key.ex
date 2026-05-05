defmodule Exy.Gateway.SessionKey do
  @moduledoc """
  Deterministic session keys for external gateway conversations.

  The rules intentionally mirror the useful Hermes gateway semantics while
  remaining explicit for Exy: DMs are isolated by chat, group chats can isolate
  by participant, and threads/topics default to shared conversations unless
  configured otherwise.
  """

  alias Exy.Gateway.Source

  @type opts :: [group_sessions_per_user: boolean(), thread_sessions_per_user: boolean()]

  @doc "Builds a deterministic gateway session key from source identity."
  @spec build(Source.t(), opts()) :: String.t()
  def build(%Source{} = source, opts \\ []) do
    group_sessions_per_user = Keyword.get(opts, :group_sessions_per_user, true)
    thread_sessions_per_user = Keyword.get(opts, :thread_sessions_per_user, false)

    case source.chat_type do
      :dm -> dm_key(source)
      _type -> group_key(source, group_sessions_per_user, thread_sessions_per_user)
    end
  end

  defp dm_key(%Source{} = source) do
    ["gateway", Atom.to_string(source.platform), "dm", source.chat_id, source.thread_id]
    |> compact_join()
  end

  defp group_key(%Source{} = source, group_sessions_per_user, thread_sessions_per_user) do
    parts = [
      "gateway",
      Atom.to_string(source.platform),
      Atom.to_string(source.chat_type),
      source.chat_id
    ]

    parts = if source.thread_id, do: parts ++ [source.thread_id], else: parts

    isolate_user? =
      group_sessions_per_user and (is_nil(source.thread_id) or thread_sessions_per_user)

    if isolate_user? and source.user_id do
      compact_join(parts ++ [source.user_id])
    else
      compact_join(parts)
    end
  end

  defp compact_join(parts) do
    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Enum.join(":")
  end
end
