defmodule Vibe.Gateway.SessionBridge do
  @moduledoc """
  Bridges Vibe session assistant stream events back to an external gateway.

  A bridge is created per accepted gateway message. It subscribes to the target
  Vibe session and forwards only assistant-facing stream events to a
  `Vibe.Gateway.StreamConsumer`, keeping Telegram/Slack/etc. delivery outside
  the session and agent internals.
  """

  use GenServer

  alias Vibe.Gateway.{Message, StreamConsumer}
  alias Vibe.UI.Event

  @spec start(Message.t(), String.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start(%Message{} = message, session_id, opts \\ []) do
    DynamicSupervisor.start_child(
      Vibe.Gateway.BridgeSupervisor,
      %{
        id: {__MODULE__, session_id, message.id || System.unique_integer([:positive])},
        start: {__MODULE__, :start_link, [[message: message, session_id: session_id] ++ opts]},
        restart: :temporary
      }
    )
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    session_id = Keyword.fetch!(opts, :session_id)
    message = Keyword.fetch!(opts, :message)

    with {:ok, session} <- Vibe.Session.lookup(session_id),
         :ok <- Vibe.Session.subscribe(session, self()) do
      {:ok,
       %{
         session: session,
         session_id: session_id,
         message: message,
         adapter: Keyword.fetch!(opts, :adapter),
         adapter_opts: Keyword.get(opts, :adapter_opts, []),
         consumer_module: Keyword.get(opts, :consumer_module, StreamConsumer),
         consumer: nil,
         stream_started?: false,
         done?: false,
         consumer_opts: Keyword.get(opts, :consumer_opts, [])
       }}
    end
  end

  @impl true
  def handle_info({Vibe.Session, :event, %Event{} = event}, state) do
    handle_event(event, state)
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state), do: {:stop, :normal, state}

  defp handle_event(%Event{type: :assistant_stream_started}, state) do
    {:noreply, %{state | stream_started?: true}}
  end

  defp handle_event(%Event{type: :assistant_delta, data: %{text: text}}, state)
       when is_binary(text) do
    case ensure_consumer(state) do
      {:ok, state} ->
        state.consumer_module.delta(state.consumer, text)
        {:noreply, state}

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  defp handle_event(%Event{type: :assistant_stream_finished, data: %{text: text}}, state) do
    state = finish_consumer(state, text)
    {:stop, :normal, state}
  end

  defp handle_event(%Event{type: :assistant_message_added, data: %{result: result}}, state) do
    text = response_text(result)
    state = send_final_message(state, text)
    {:stop, :normal, state}
  end

  defp handle_event(%Event{type: :assistant_message_added, data: %{error: error}}, state) do
    state = send_final_message(state, error)
    {:stop, :normal, state}
  end

  defp handle_event(%Event{type: :assistant_aborted, data: %{reason: reason}}, state) do
    state = send_final_message(state, reason || "Request cancelled.")
    {:stop, :normal, state}
  end

  defp handle_event(_event, state), do: {:noreply, state}

  defp ensure_consumer(%{consumer: pid} = state) when is_pid(pid), do: {:ok, state}

  defp ensure_consumer(state) do
    opts =
      [
        adapter: state.adapter,
        chat_id: state.message.source.chat_id,
        adapter_opts: adapter_opts(state),
        reply_to: state.message.id
      ]
      |> Keyword.merge(state.consumer_opts)

    case state.consumer_module.start_link(opts) do
      {:ok, pid} -> {:ok, %{state | consumer: pid}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp finish_consumer(%{consumer: nil} = state, text) when is_binary(text) and text != "" do
    send_final_message(state, text)
  end

  defp finish_consumer(%{consumer: nil} = state, _text), do: state

  defp finish_consumer(%{consumer: pid} = state, _text) do
    state.consumer_module.finish(pid)
    %{state | done?: true}
  end

  defp send_final_message(state, text) when is_binary(text) and text != "" do
    _ignored = state.adapter.send(state.message.source.chat_id, text, send_opts(state))
    %{state | done?: true}
  end

  defp send_final_message(state, _text), do: state

  defp adapter_opts(state) do
    state.adapter_opts
    |> Keyword.put_new(:thread_id, state.message.source.thread_id)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp send_opts(state) do
    state
    |> adapter_opts()
    |> Keyword.put_new(:reply_to, state.message.id)
  end

  defp response_text(text) when is_binary(text), do: text

  defp response_text(%ReqLLM.Response{} = response) do
    ReqLLM.Response.text(response) || inspect(response)
  end

  defp response_text(%{output: output}) when is_binary(output), do: output
  defp response_text(response), do: inspect(response)
end
