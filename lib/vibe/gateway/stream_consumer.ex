defmodule Vibe.Gateway.StreamConsumer do
  @moduledoc """
  Converts streamed assistant text into throttled gateway message edits.

  The consumer is platform-neutral. It receives semantic text deltas and uses an
  `Vibe.Gateway.Adapter` implementation to send the first visible message, edit
  it as content grows, and finalize it without a cursor. Telegram is the first
  target, but the rules are intentionally generic and BEAM-native.
  """

  use GenServer

  @default_edit_interval_ms 1_000
  @default_buffer_threshold 40
  @default_cursor " ▉"

  defstruct adapter: nil,
            chat_id: nil,
            adapter_opts: [],
            edit_interval_ms: @default_edit_interval_ms,
            buffer_threshold: @default_buffer_threshold,
            cursor: @default_cursor,
            max_message_length: 4_096,
            accumulated: "",
            visible_text: "",
            message_id: nil,
            last_edit_ms: 0,
            done?: false,
            timer: nil,
            reply_to: nil

  @type t :: %__MODULE__{}

  @type option ::
          {:adapter, module()}
          | {:chat_id, String.t()}
          | {:adapter_opts, keyword()}
          | {:edit_interval_ms, pos_integer()}
          | {:buffer_threshold, pos_integer()}
          | {:cursor, String.t()}
          | {:max_message_length, pos_integer()}
          | {:reply_to, String.t() | nil}

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @spec delta(pid(), String.t()) :: :ok
  def delta(pid, text) when is_pid(pid) and is_binary(text),
    do: GenServer.cast(pid, {:delta, text})

  @spec segment_break(pid()) :: :ok
  def segment_break(pid) when is_pid(pid), do: GenServer.cast(pid, :segment_break)

  @spec finish(pid()) :: :ok
  def finish(pid) when is_pid(pid), do: GenServer.cast(pid, :finish)

  @impl true
  def init(opts) do
    state = %__MODULE__{
      adapter: Keyword.fetch!(opts, :adapter),
      chat_id: Keyword.fetch!(opts, :chat_id),
      adapter_opts: Keyword.get(opts, :adapter_opts, []),
      edit_interval_ms: Keyword.get(opts, :edit_interval_ms, @default_edit_interval_ms),
      buffer_threshold: Keyword.get(opts, :buffer_threshold, @default_buffer_threshold),
      cursor: Keyword.get(opts, :cursor, @default_cursor),
      max_message_length: Keyword.get(opts, :max_message_length, 4_096),
      reply_to: Keyword.get(opts, :reply_to)
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:delta, text}, state) do
    state = %{state | accumulated: state.accumulated <> filter_display_text(text)}

    if flush_due?(state) do
      {:noreply, flush(state, finalize?: false)}
    else
      {:noreply, schedule_flush(state)}
    end
  end

  def handle_cast(:segment_break, state) do
    state =
      state
      |> flush(finalize?: true)
      |> reset_message()

    {:noreply, state}
  end

  def handle_cast(:finish, state) do
    state = flush(%{state | done?: true}, finalize?: true)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:flush, state) do
    {:noreply, flush(%{state | timer: nil}, finalize?: false)}
  end

  @doc "Removes gateway-internal directives that should never be shown to users."
  @spec filter_display_text(String.t()) :: String.t()
  def filter_display_text(text) when is_binary(text) do
    text
    |> String.replace(~r/[`"']?MEDIA:\s*\S+[`"']?/, "")
    |> String.replace("[[audio_as_voice]]", "")
  end

  defp flush_due?(%__MODULE__{} = state) do
    byte_size(state.accumulated) >= state.buffer_threshold or
      now_ms() - state.last_edit_ms >= state.edit_interval_ms
  end

  defp schedule_flush(%__MODULE__{timer: timer} = state) when is_reference(timer), do: state

  defp schedule_flush(%__MODULE__{} = state) do
    %{state | timer: Process.send_after(self(), :flush, state.edit_interval_ms)}
  end

  defp flush(%__MODULE__{accumulated: ""} = state, _opts), do: state

  defp flush(%__MODULE__{} = state, opts) do
    finalize? = Keyword.get(opts, :finalize?, false)
    text = render_text(state, finalize?)

    cond do
      cursor_only?(text, state.cursor) ->
        state

      text == state.visible_text and not finalize? ->
        state

      true ->
        deliver(state, text, finalize?)
    end
  end

  defp render_text(state, true), do: state.accumulated
  defp render_text(state, false), do: state.accumulated <> state.cursor

  defp cursor_only?(text, cursor) do
    text =
      text
      |> String.replace(cursor, "")
      |> String.trim()

    text == ""
  end

  defp deliver(%__MODULE__{message_id: nil} = state, text, _finalize?) do
    case state.adapter.send(
           state.chat_id,
           limit_text(text, state.max_message_length),
           send_opts(state)
         ) do
      {:ok, message_id} ->
        %{state | message_id: message_id, visible_text: text, last_edit_ms: now_ms()}

      {:error, _reason} ->
        %{state | last_edit_ms: now_ms()}
    end
  end

  defp deliver(%__MODULE__{} = state, text, finalize?) do
    case state.adapter.edit(
           state.chat_id,
           state.message_id,
           limit_text(text, state.max_message_length),
           Keyword.put(state.adapter_opts, :finalize?, finalize?)
         ) do
      {:ok, _message_id} ->
        %{state | visible_text: text, last_edit_ms: now_ms()}

      {:error, _reason} ->
        %{state | last_edit_ms: now_ms()}
    end
  end

  defp send_opts(%__MODULE__{} = state) do
    state.adapter_opts
    |> Keyword.put_new(:reply_to, state.reply_to)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp reset_message(%__MODULE__{} = state) do
    %{state | accumulated: "", visible_text: "", message_id: nil, reply_to: nil}
  end

  defp limit_text(text, max_length) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length - 1) <> "…"
    end
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
