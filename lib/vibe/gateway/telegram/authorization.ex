defmodule Vibe.Gateway.Telegram.Authorization do
  @moduledoc """
  Authorization and group trigger rules for Telegram gateway messages.

  This mirrors the useful separation in Hermes: a message can pass the group
  trigger gate (mention/reply/free-response chat) and still be rejected by user
  or chat allowlists before it reaches a Vibe session.
  """

  alias Vibe.Gateway.Source
  alias Vibe.Gateway.Telegram.Config

  @spec authorized?(Source.t(), Config.t()) :: boolean()
  def authorized?(%Source{} = source, %Config{} = config) do
    cond do
      config.allow_all? ->
        true

      source.chat_type in [:group, :forum] and
          allowed_chat?(source.chat_id, config.group_allowed_chats) ->
        true

      allowed_user?(source.user_id, config.allowed_users) ->
        true

      source.chat_type in [:group, :forum] and
          allowed_user?(source.user_id, config.group_allowed_users) ->
        true

      true ->
        false
    end
  end

  @spec trigger_allowed?(Source.t(), map(), Config.t()) :: boolean()
  def trigger_allowed?(%Source{chat_type: :dm}, _trigger, _config), do: true
  def trigger_allowed?(%Source{chat_type: :channel}, _trigger, _config), do: true

  def trigger_allowed?(%Source{} = source, trigger, %Config{} = config) do
    cond do
      ignored_thread?(source.thread_id, config.ignored_threads) -> false
      allowed_chat?(source.chat_id, config.free_response_chats) -> true
      not config.require_mention? -> true
      Map.get(trigger, :reply_to_bot?, false) -> true
      Map.get(trigger, :mentions_bot?, false) -> true
      Map.get(trigger, :matches_wake_pattern?, false) -> true
      true -> false
    end
  end

  defp allowed_user?(nil, _allowed), do: false

  defp allowed_user?(user_id, allowed),
    do: MapSet.member?(allowed, "*") or MapSet.member?(allowed, user_id)

  defp allowed_chat?(nil, _allowed), do: false

  defp allowed_chat?(chat_id, allowed),
    do: MapSet.member?(allowed, "*") or MapSet.member?(allowed, chat_id)

  defp ignored_thread?(nil, _ignored), do: false

  defp ignored_thread?(thread_id, ignored) do
    case Integer.parse(to_string(thread_id)) do
      {int, ""} -> MapSet.member?(ignored, int)
      _other -> false
    end
  end
end
