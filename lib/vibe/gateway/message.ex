defmodule Vibe.Gateway.Message do
  @moduledoc """
  Normalized inbound message from an external chat gateway.

  Platform adapters should download/copy media to local files or session
  artifacts before constructing this struct. The rest of Vibe can then process
  text, attachments, source identity, and replies without depending on Telegram
  or any other platform SDK.
  """

  alias Vibe.Gateway.{Media, Options, Source}

  @message_types [:text, :command, :photo, :video, :audio, :voice, :document, :sticker, :location]

  @enforce_keys [:source]
  defstruct text: "",
            type: :text,
            source: nil,
            id: nil,
            platform_update_id: nil,
            media: [],
            reply_to_message_id: nil,
            reply_to_text: nil,
            timestamp: nil,
            metadata: %{}

  @type message_type ::
          :text | :command | :photo | :video | :audio | :voice | :document | :sticker | :location

  @type media :: %{path: String.t(), mime_type: String.t() | nil, filename: String.t() | nil}

  @type t :: %__MODULE__{
          text: String.t(),
          type: message_type(),
          source: Source.t(),
          id: String.t() | nil,
          platform_update_id: String.t() | integer() | nil,
          media: [media()],
          reply_to_message_id: String.t() | nil,
          reply_to_text: String.t() | nil,
          timestamp: DateTime.t() | nil,
          metadata: map()
        }

  @doc "Builds a normalized gateway message."
  @spec new(Source.t(), keyword()) :: t()
  def new(%Source{} = source, opts \\ []) do
    %__MODULE__{
      source: source,
      text: Keyword.get(opts, :text, "") || "",
      type: type!(Keyword.get(opts, :type, :text)),
      id: Options.optional_string(opts, :id),
      platform_update_id: Keyword.get(opts, :platform_update_id),
      media: normalize_media(Keyword.get(opts, :media, [])),
      reply_to_message_id: Options.optional_string(opts, :reply_to_message_id),
      reply_to_text: Options.optional_string(opts, :reply_to_text),
      timestamp: Keyword.get(opts, :timestamp),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc "Returns true when the message text starts with a slash command."
  @spec command?(t()) :: boolean()
  def command?(%__MODULE__{text: "/" <> _}), do: true
  def command?(_message), do: false

  @doc "Extracts a slash command name without the leading slash or bot suffix."
  @spec command(t()) :: String.t() | nil
  def command(%__MODULE__{text: text}) do
    with true <- is_binary(text),
         [raw | _rest] <- String.split(text, ~r/\s+/, parts: 2),
         "/" <> command <- raw,
         false <- String.contains?(command, "/") do
      command
      |> String.split("@", parts: 2)
      |> hd()
      |> String.downcase()
    else
      _ -> nil
    end
  end

  @doc "Returns the text after a slash command, normalizing common mobile dash substitutions."
  @spec command_args(t()) :: String.t()
  def command_args(%__MODULE__{text: text} = message) when is_binary(text) do
    if command?(message) do
      case String.split(text, ~r/\s+/, parts: 2) do
        [_command, args] -> normalize_dashes(args)
        _other -> ""
      end
    else
      text
    end
  end

  defp normalize_media(media) when is_list(media), do: Enum.map(media, &normalize_media_entry/1)

  defp normalize_media(_media), do: []

  defp normalize_media_entry(media) when is_map(media) do
    media = normalize_media_keys(media)
    path = Map.get(media, :path)

    if is_binary(path) do
      %Media{
        path: path,
        mime_type: Map.get(media, :mime_type),
        filename: Map.get(media, :filename)
      }
    else
      raise ArgumentError, "gateway media entry requires a path"
    end
  end

  defp normalize_media_entry(path) when is_binary(path), do: %Media{path: path}

  defp type!(type) when type in @message_types, do: type

  defp type!(type) when is_binary(type) do
    atom = String.to_existing_atom(type)
    type!(atom)
  rescue
    _exception in ArgumentError ->
      reraise ArgumentError,
              [message: "invalid gateway message type #{inspect(type)}"],
              __STACKTRACE__
  end

  defp type!(type), do: raise(ArgumentError, "invalid gateway message type #{inspect(type)}")

  defp normalize_media_keys(media) do
    media
    |> Map.take([:path, :mime_type, :filename, "path", "mime_type", "filename"])
    |> Enum.reduce(%{}, fn
      {key, value}, acc when is_binary(key) ->
        Map.put_new(acc, String.to_existing_atom(key), value)

      {key, value}, acc when is_atom(key) ->
        Map.put(acc, key, value)
    end)
  end

  defp normalize_dashes(text) do
    text
    |> String.replace("——", "--")
    |> String.replace("—", "--")
    |> String.replace("–", "-")
  end
end
