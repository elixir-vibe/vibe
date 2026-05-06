defmodule Vibe.Gateway.Dispatcher do
  @moduledoc """
  Dispatches normalized gateway messages into Vibe semantic sessions.

  This module is intentionally gateway-neutral. Platform adapters submit
  `%Vibe.Gateway.Message{}` values to the runtime; the dispatcher maps those
  messages onto deterministic Vibe session ids and submits regular session
  commands.
  """

  alias Vibe.Gateway.{Message, SessionKey}
  alias Vibe.UI.Command

  @type option :: {:session_key_opts, SessionKey.opts()} | {:session_opts, keyword()}

  @doc "Finds or starts the target session and submits the gateway message text."
  @spec dispatch(Message.t(), [option()]) :: {:ok, String.t()} | {:error, term()}
  def dispatch(%Message{} = message, opts \\ []) do
    session_id = SessionKey.build(message.source, Keyword.get(opts, :session_key_opts, []))
    session_opts = Keyword.get(opts, :session_opts, [])

    with {:ok, session} <- find_or_start_session(session_id, message, session_opts),
         :ok <- maybe_after_session(message, session_id, session, opts),
         :ok <-
           Vibe.Session.dispatch(
             session,
             Command.new(:submit_prompt, %{text: prompt_text(message)})
           ) do
      {:ok, session_id}
    end
  end

  defp maybe_after_session(message, session_id, session, opts) do
    case Keyword.get(opts, :after_session) do
      fun when is_function(fun, 3) -> fun.(message, session_id, session)
      _missing -> :ok
    end
  end

  defp find_or_start_session(session_id, message, session_opts) do
    case Vibe.Session.lookup(session_id) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, :not_found} ->
        Vibe.Session.start(
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
