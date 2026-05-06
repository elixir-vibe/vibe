defmodule Vibe.Gateway.Telegram.StreamConsumer do
  @moduledoc """
  Telegram-specific assistant stream consumer.

  Draft mode uses Telegram's `sendMessageDraft` for transient partial text in
  private chats, then sends the final assistant message normally. Edit mode stays
  in the generic `Vibe.Gateway.StreamConsumer`; this module exists for `:draft`
  and `:auto` bridge policies.
  """

  use GenServer

  @default_buffer_threshold 40
  @default_interval_ms 1_000

  defstruct adapter: nil,
            chat_id: nil,
            adapter_opts: [],
            draft_fun: nil,
            draft_id: nil,
            accumulated: "",
            visible_text: "",
            buffer_threshold: @default_buffer_threshold,
            edit_interval_ms: @default_interval_ms,
            last_draft_ms: 0,
            timer: nil,
            max_message_length: 4_096,
            reply_to: nil

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec delta(pid(), String.t()) :: :ok
  def delta(pid, text) when is_pid(pid) and is_binary(text),
    do: GenServer.cast(pid, {:delta, text})

  @spec finish(pid()) :: :ok
  def finish(pid) when is_pid(pid), do: GenServer.cast(pid, :finish)

  @impl true
  def init(opts) do
    {:ok,
     %__MODULE__{
       adapter: Keyword.fetch!(opts, :adapter),
       chat_id: Keyword.fetch!(opts, :chat_id),
       adapter_opts: Keyword.get(opts, :adapter_opts, []),
       draft_fun: Keyword.get(opts, :draft_fun, &ExGram.send_message_draft/4),
       draft_id: Keyword.get_lazy(opts, :draft_id, &new_draft_id/0),
       buffer_threshold: Keyword.get(opts, :buffer_threshold, @default_buffer_threshold),
       edit_interval_ms: Keyword.get(opts, :edit_interval_ms, @default_interval_ms),
       max_message_length: Keyword.get(opts, :max_message_length, 4_096),
       reply_to: Keyword.get(opts, :reply_to)
     }}
  end

  @impl true
  def handle_cast({:delta, text}, state) do
    state = %{
      state
      | accumulated: state.accumulated <> Vibe.Gateway.StreamConsumer.filter_display_text(text)
    }

    if flush_due?(state), do: {:noreply, flush(state)}, else: {:noreply, schedule_flush(state)}
  end

  def handle_cast(:finish, state) do
    state = flush(%{state | timer: nil})

    _ignored =
      state.adapter.send(
        state.chat_id,
        state.accumulated,
        send_opts(state)
      )

    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:flush, state), do: {:noreply, flush(%{state | timer: nil})}

  defp flush(%__MODULE__{accumulated: ""} = state), do: state

  defp flush(state) do
    text =
      state.accumulated
      |> limit_text(state.max_message_length)
      |> Vibe.Gateway.Telegram.Text.to_html()

    if text == state.visible_text do
      state
    else
      case state.draft_fun.(
             String.to_integer(state.chat_id),
             state.draft_id,
             text,
             Keyword.put(draft_opts(state), :parse_mode, "HTML")
           ) do
        {:ok, true} -> %{state | visible_text: text, last_draft_ms: now_ms()}
        {:ok, _other} -> %{state | visible_text: text, last_draft_ms: now_ms()}
        {:error, _reason} -> %{state | last_draft_ms: now_ms()}
      end
    end
  rescue
    _error -> %{state | last_draft_ms: now_ms()}
  end

  defp flush_due?(state) do
    byte_size(state.accumulated) >= state.buffer_threshold or
      now_ms() - state.last_draft_ms >= state.edit_interval_ms
  end

  defp schedule_flush(%__MODULE__{timer: timer} = state) when is_reference(timer), do: state

  defp schedule_flush(state),
    do: %{state | timer: Process.send_after(self(), :flush, state.edit_interval_ms)}

  defp draft_opts(state) do
    case Keyword.get(state.adapter_opts, :config) do
      %{token: token} -> [token: token]
      _missing -> Keyword.take(state.adapter_opts, [:token])
    end
  end

  defp send_opts(state) do
    state.adapter_opts
    |> Keyword.put_new(:reply_to, state.reply_to)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp limit_text(text, max_length) do
    if String.length(text) <= max_length,
      do: text,
      else: String.slice(text, 0, max_length - 1) <> "…"
  end

  defp new_draft_id, do: System.unique_integer([:positive])
  defp now_ms, do: System.monotonic_time(:millisecond)
end
