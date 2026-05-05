defmodule Exy.Gateway.Dispatcher do
  @moduledoc """
  Dispatches normalized gateway messages into Exy semantic sessions.

  This module is intentionally gateway-neutral. Platform adapters submit
  `%Exy.Gateway.Message{}` values to the runtime; the dispatcher maps those
  messages onto deterministic Exy session ids and submits regular session
  commands.
  """

  alias Exy.Gateway.{Message, SessionKey}
  alias Exy.UI.Command

  @type option :: {:session_key_opts, SessionKey.opts()} | {:session_opts, keyword()}

  @doc "Finds or starts the target session and submits the gateway message text."
  @spec dispatch(Message.t(), [option()]) :: {:ok, String.t()} | {:error, term()}
  def dispatch(%Message{} = message, opts \\ []) do
    session_id = SessionKey.build(message.source, Keyword.get(opts, :session_key_opts, []))
    session_opts = Keyword.get(opts, :session_opts, [])

    with {:ok, session} <- find_or_start_session(session_id, message, session_opts),
         :ok <-
           Exy.Session.dispatch(
             session,
             Command.new(:submit_prompt, %{text: prompt_text(message)})
           ) do
      {:ok, session_id}
    end
  end

  defp find_or_start_session(session_id, message, session_opts) do
    case Exy.Session.lookup(session_id) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        Exy.Session.start(
          Keyword.merge(session_opts,
            session_id: session_id,
            cwd: File.cwd!(),
            title: session_title(message)
          )
        )
    end
  end

  defp prompt_text(%Message{reply_to_text: nil, text: text}), do: text

  defp prompt_text(%Message{reply_to_text: reply, text: text}) do
    "Replying to:\n#{reply}\n\n#{text}"
  end

  defp session_title(%Message{} = message) do
    case message.source.chat_name do
      nil -> "Gateway #{message.source.platform}:#{message.source.chat_id}"
      name -> "#{message.source.platform}: #{name}"
    end
  end
end
