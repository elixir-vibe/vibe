defmodule Exy.Gateway.Source do
  @moduledoc """
  Origin metadata for a message entering Exy through an external gateway.

  Gateway adapters translate platform-specific updates into this struct before
  they touch sessions. Keeping source identity explicit lets Telegram, future
  chat backends, and scheduled delivery share one session-key and authorization
  model without leaking platform SDK structs into agent code.
  """

  @enforce_keys [:platform, :chat_id, :chat_type]
  defstruct [
    :platform,
    :chat_id,
    :chat_name,
    :chat_type,
    :user_id,
    :user_name,
    :thread_id,
    :chat_topic,
    :message_id
  ]

  @type chat_type :: :dm | :group | :channel | :thread | :forum

  @type t :: %__MODULE__{
          platform: atom(),
          chat_id: String.t(),
          chat_name: String.t() | nil,
          chat_type: chat_type(),
          user_id: String.t() | nil,
          user_name: String.t() | nil,
          thread_id: String.t() | nil,
          chat_topic: String.t() | nil,
          message_id: String.t() | nil
        }

  @doc "Builds a source struct from platform identity fields."
  @spec new(atom(), keyword()) :: t()
  def new(platform, opts) when is_atom(platform) and is_list(opts) do
    %__MODULE__{
      platform: platform,
      chat_id: required_string!(opts, :chat_id),
      chat_name: optional_string(opts, :chat_name),
      chat_type: chat_type!(Keyword.get(opts, :chat_type, :dm)),
      user_id: optional_string(opts, :user_id),
      user_name: optional_string(opts, :user_name),
      thread_id: optional_string(opts, :thread_id),
      chat_topic: optional_string(opts, :chat_topic),
      message_id: optional_string(opts, :message_id)
    }
  end

  @doc "Returns a compact human-readable description for prompts and logs."
  @spec description(t()) :: String.t()
  def description(%__MODULE__{} = source) do
    base =
      case source.chat_type do
        :dm -> "DM with #{source.user_name || source.user_id || source.chat_id}"
        type -> "#{type}: #{source.chat_name || source.chat_id}"
      end

    case source.thread_id do
      nil -> base
      thread_id -> base <> ", thread: " <> thread_id
    end
  end

  defp required_string!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_binary(value) and value != "" -> value
      {:ok, value} when is_integer(value) -> Integer.to_string(value)
      _other -> raise ArgumentError, "missing required gateway source #{key}"
    end
  end

  defp optional_string(opts, key) do
    case Keyword.get(opts, key) do
      nil -> nil
      "" -> nil
      value when is_binary(value) -> value
      value when is_integer(value) -> Integer.to_string(value)
      value -> to_string(value)
    end
  end

  defp chat_type!(type) when type in [:dm, :group, :channel, :thread, :forum], do: type

  defp chat_type!(type) when is_binary(type) do
    type
    |> String.downcase()
    |> String.to_existing_atom()
    |> chat_type!()
  rescue
    _exception in ArgumentError ->
      reraise ArgumentError,
              [message: "invalid gateway chat_type #{inspect(type)}"],
              __STACKTRACE__
  end

  defp chat_type!(type), do: raise(ArgumentError, "invalid gateway chat_type #{inspect(type)}")
end
