defmodule Vibe.Gateway.Telegram.Update do
  @moduledoc """
  Converts Telegram update maps/structs into Vibe gateway messages.

  This module is the explicit boundary for Telegram's string/atom-keyed payloads.
  It accepts ExGram structs, decoded JSON maps, or test doubles by reading only
  known Bot API fields and emitting `%Vibe.Gateway.Message{}` plus trigger
  metadata for group gating.
  """

  alias Vibe.Gateway.{Message, Source}

  @general_topic_thread_id "1"

  @type normalized :: %{message: Message.t(), trigger: map()}

  @doc "Normalizes a Telegram update into a Vibe gateway message."
  @spec normalize(term(), keyword()) :: {:ok, normalized()} | :ignore | {:error, term()}
  def normalize(update, opts \\ []) do
    bot_id = optional_string(opts, :bot_id)
    bot_username = opts |> optional_string(:bot_username) |> trim_username()

    with {:ok, message} <- update_message(update),
         {:ok, source} <- source(message),
         {:ok, type} <- message_type(message) do
      text = message_text(message)

      {:ok,
       %{
         message:
           Message.new(source,
             text: text,
             type: type,
             id: optional_field(message, :message_id),
             platform_update_id: optional_field(update, :update_id),
             media: media(message, type),
             reply_to_message_id: reply_to_message_id(message),
             reply_to_text: reply_to_text(message)
           ),
         trigger: %{
           mentions_bot?: mentions_bot?(message, bot_username, bot_id),
           reply_to_bot?: reply_to_bot?(message, bot_id)
         }
       }}
    end
  end

  defp update_message(update) do
    cond do
      value = field(update, :message) -> {:ok, value}
      value = field(update, :edited_message) -> {:ok, value}
      true -> :ignore
    end
  end

  defp source(message) do
    case field(message, :chat) do
      nil ->
        {:error, :telegram_chat_missing}

      chat ->
        chat_type = chat_type(chat)
        thread_id = thread_id(message, chat_type)

        {:ok,
         Source.new(:telegram,
           chat_id: required_field(chat, :id),
           chat_name: chat_title(chat),
           chat_type: chat_type,
           user_id: user_id(message, chat),
           user_name: user_name(message, chat),
           thread_id: thread_id,
           message_id: optional_field(message, :message_id)
         )}
    end
  end

  defp message_type(message) do
    cond do
      text = field(message, :text) ->
        if String.starts_with?(to_string(text), "/"), do: {:ok, :command}, else: {:ok, :text}

      field(message, :location) || field(message, :venue) ->
        {:ok, :location}

      field(message, :photo) ->
        {:ok, :photo}

      field(message, :video) ->
        {:ok, :video}

      field(message, :audio) ->
        {:ok, :audio}

      field(message, :voice) ->
        {:ok, :voice}

      field(message, :document) ->
        {:ok, :document}

      field(message, :sticker) ->
        {:ok, :sticker}

      true ->
        :ignore
    end
  end

  defp message_text(message) do
    cond do
      text = field(message, :text) -> to_string(text)
      caption = field(message, :caption) -> to_string(caption)
      field(message, :location) || field(message, :venue) -> location_text(message)
      true -> ""
    end
  end

  defp media(message, :photo) do
    case field(message, :photo) do
      sizes when is_list(sizes) ->
        sizes
        |> List.last()
        |> file_media("image/jpeg")
        |> List.wrap()

      _other ->
        []
    end
  end

  defp media(message, :document),
    do:
      message
      |> field(:document)
      |> file_media(mime_type(field(message, :document)))
      |> List.wrap()

  defp media(message, :voice),
    do: message |> field(:voice) |> file_media("audio/ogg") |> List.wrap()

  defp media(message, :audio),
    do:
      message
      |> field(:audio)
      |> file_media(mime_type(field(message, :audio)) || "audio/mpeg")
      |> List.wrap()

  defp media(message, :video),
    do:
      message
      |> field(:video)
      |> file_media(mime_type(field(message, :video)) || "video/mp4")
      |> List.wrap()

  defp media(_message, _type), do: []

  defp file_media(nil, _mime_type), do: nil

  defp file_media(file, mime_type) do
    file_id = optional_field(file, :file_id)

    if file_id do
      %{
        path: "telegram:file_id:#{file_id}",
        mime_type: mime_type,
        filename: optional_field(file, :file_name)
      }
    end
  end

  defp mime_type(nil), do: nil
  defp mime_type(value), do: optional_field(value, :mime_type)

  defp location_text(message) do
    location = field(field(message, :venue) || message, :location)
    latitude = field(location, :latitude)
    longitude = field(location, :longitude)

    [
      "[The user shared a location pin.]",
      "latitude: #{latitude}",
      "longitude: #{longitude}",
      "Map: https://www.google.com/maps/search/?api=1&query=#{latitude},#{longitude}"
    ]
    |> Enum.join("\n")
  end

  defp chat_type(chat) do
    case field(chat, :type) |> to_string() |> String.downcase() do
      "private" -> :dm
      "group" -> :group
      "supergroup" -> :group
      "channel" -> :channel
      _other -> :group
    end
  end

  defp thread_id(message, :group) do
    case optional_field(message, :message_thread_id) do
      nil -> if truthy?(field(field(message, :chat), :is_forum)), do: @general_topic_thread_id
      value -> value
    end
  end

  defp thread_id(message, :dm), do: optional_field(message, :message_thread_id)

  defp thread_id(_message, _chat_type), do: nil

  defp chat_title(chat), do: optional_field(chat, :title) || optional_field(chat, :full_name)

  defp user_id(message, chat) do
    case field(message, :from) do
      nil -> if chat_type(chat) == :dm, do: optional_field(chat, :id)
      user -> optional_field(user, :id)
    end
  end

  defp user_name(message, chat) do
    case field(message, :from) do
      nil -> if chat_type(chat) == :dm, do: chat_title(chat)
      user -> full_name(user)
    end
  end

  defp full_name(user) do
    [optional_field(user, :first_name), optional_field(user, :last_name)]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> optional_field(user, :username)
      name -> name
    end
  end

  defp reply_to_message_id(message) do
    message
    |> field(:reply_to_message)
    |> optional_field(:message_id)
  end

  defp reply_to_text(message) do
    case field(message, :reply_to_message) do
      nil -> nil
      reply -> optional_field(reply, :text) || optional_field(reply, :caption)
    end
  end

  defp reply_to_bot?(_message, nil), do: false

  defp reply_to_bot?(message, bot_id) do
    reply_user = message |> field(:reply_to_message) |> field(:from)
    optional_field(reply_user, :id) == bot_id
  end

  defp mentions_bot?(_message, nil, _bot_id), do: false

  defp mentions_bot?(message, bot_username, bot_id) do
    Enum.any?(entity_sources(message), fn {text, entities} ->
      Enum.any?(entities, fn entity ->
        entity_mentions_bot?(entity, text, bot_username, bot_id)
      end)
    end)
  end

  defp entity_sources(message) do
    [
      {optional_field(message, :text) || "", field(message, :entities) || []},
      {optional_field(message, :caption) || "", field(message, :caption_entities) || []}
    ]
  end

  defp entity_mentions_bot?(entity, text, bot_username, bot_id) do
    case optional_field(entity, :type) do
      "mention" ->
        entity_text(text, entity) == "@#{bot_username}"

      "bot_command" ->
        String.ends_with?(String.downcase(entity_text(text, entity)), "@#{bot_username}")

      "text_mention" ->
        optional_field(field(entity, :user), :id) == bot_id

      _other ->
        false
    end
  end

  defp entity_text(text, entity) do
    offset = field(entity, :offset) || 0
    length = field(entity, :length) || 0

    text
    |> utf16_slice(offset, length)
    |> String.downcase()
  end

  defp utf16_slice(text, offset, length) do
    text
    |> String.graphemes()
    |> Enum.reduce({0, ""}, fn grapheme, {position, acc} ->
      next_position = position + utf16_length(grapheme)

      cond do
        next_position <= offset -> {next_position, acc}
        position >= offset + length -> {next_position, acc}
        true -> {next_position, acc <> grapheme}
      end
    end)
    |> elem(1)
  end

  defp utf16_length(text),
    do: div(byte_size(:unicode.characters_to_binary(text, :utf8, {:utf16, :little})), 2)

  defp required_field(value, key) do
    value
    |> field(key)
    |> to_string()
  end

  defp optional_field(nil, _key), do: nil
  defp optional_field(value, key), do: value |> field(key) |> optional_to_string()

  defp optional_string(opts, key) do
    opts
    |> Keyword.get(key)
    |> optional_to_string()
  end

  defp optional_to_string(nil), do: nil
  defp optional_to_string(""), do: nil
  defp optional_to_string(value) when is_binary(value), do: value
  defp optional_to_string(value), do: to_string(value)

  defp trim_username(nil), do: nil
  defp trim_username(username), do: username |> String.trim_leading("@") |> String.downcase()

  defp field(nil, _key), do: nil

  defp field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp truthy?(value), do: value in [true, "true", 1, "1"]
end
