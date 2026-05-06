defmodule Exy.Gateway.Telegram.Adapter do
  @moduledoc """
  Outbound Telegram Bot API adapter for the generic Exy gateway contract.

  This module intentionally uses ExGram's low-level API. Inbound update polling
  and webhook supervision can be added around the same adapter without changing
  stream consumers or session code.
  """

  @behaviour Exy.Gateway.Adapter

  alias Exy.Gateway.Telegram.{Config, Text}

  @impl Exy.Gateway.Adapter
  def send(chat_id, text, opts) do
    config = Keyword.fetch!(opts, :config)

    case send_html_chunks(chat_id, text, common_opts(opts, config)) do
      {:ok, message_id} -> {:ok, message_id}
      {:error, reason} -> send_plain(chat_id, text, opts, reason)
    end
  end

  @impl Exy.Gateway.Adapter
  def edit(chat_id, message_id, text, opts) do
    config = Keyword.fetch!(opts, :config)

    telegram_opts =
      opts
      |> common_opts(config)
      |> Keyword.merge(chat_id: chat_id, message_id: message_id, parse_mode: "HTML")

    text = text |> Text.limit(4_096) |> Text.to_html()

    case ExGram.edit_message_text(text, telegram_opts) do
      {:ok, message} ->
        {:ok, message_id(message) || to_string(message_id)}

      {:error, %ExGram.Error{message: message}} when is_binary(message) ->
        if String.contains?(String.downcase(message), "message is not modified"),
          do: {:ok, to_string(message_id)},
          else: edit_plain(chat_id, message_id, text, opts, message)

      {:error, reason} ->
        edit_plain(chat_id, message_id, text, opts, reason)
    end
  end

  @impl Exy.Gateway.Adapter
  def delete(chat_id, message_id, opts) do
    config = Keyword.fetch!(opts, :config)

    case ExGram.delete_message(chat_id, message_id, token: config.token) do
      {:ok, true} -> :ok
      {:ok, _other} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Exy.Gateway.Adapter
  def typing(chat_id, opts) do
    config = Keyword.fetch!(opts, :config)

    case ExGram.send_chat_action(chat_id, "typing", token: config.token) do
      {:ok, true} -> :ok
      {:ok, _other} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_html_chunks(chat_id, text, opts) do
    text
    |> Text.html_chunks()
    |> Enum.reduce_while(nil, fn chunk, first_message_id ->
      case ExGram.send_message(chat_id, chunk, Keyword.put(opts, :parse_mode, "HTML")) do
        {:ok, message} -> {:cont, first_message_id || message_id(message)}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:error, reason} -> {:error, reason}
      message_id -> {:ok, message_id}
    end
  end

  defp send_plain(chat_id, text, opts, markdown_error) do
    config = Keyword.fetch!(opts, :config)

    case ExGram.send_message(chat_id, text, common_opts(opts, config)) do
      {:ok, message} -> {:ok, message_id(message)}
      {:error, reason} -> {:error, {:telegram_send_failed, markdown_error, reason}}
    end
  end

  defp edit_plain(chat_id, message_id, text, opts, markdown_error) do
    config = Keyword.fetch!(opts, :config)

    opts = opts |> common_opts(config) |> Keyword.merge(chat_id: chat_id, message_id: message_id)

    case ExGram.edit_message_text(text, opts) do
      {:ok, message} -> {:ok, message_id(message) || to_string(message_id)}
      {:error, reason} -> {:error, {:telegram_edit_failed, markdown_error, reason}}
    end
  end

  defp common_opts(opts, %Config{} = config) do
    [token: config.token]
    |> maybe_put(:reply_to_message_id, Keyword.get(opts, :reply_to))
    |> maybe_put(:message_thread_id, thread_id(opts))
  end

  defp thread_id(opts) do
    case Keyword.get(opts, :thread_id) do
      nil -> nil
      "1" -> nil
      1 -> nil
      value -> value
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp message_id(%{message_id: id}) when not is_nil(id), do: to_string(id)
  defp message_id(_message), do: nil
end
