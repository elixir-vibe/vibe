defmodule Exy.Gateway.Telegram.Polling do
  @moduledoc """
  Telegram long-polling inbound transport for the generic gateway runtime.

  The process owns Bot API polling details and submits raw Telegram updates to
  `Exy.Gateway.Runtime`. It clears stale webhooks before polling by default,
  matching Hermes' operational guardrail for switching between webhook and
  polling modes.
  """

  use GenServer

  alias Exy.Gateway.Runtime

  require Logger

  @default_interval_ms 100
  @default_timeout_s 5

  defstruct token: nil,
            runtime: nil,
            offset: -1,
            interval_ms: @default_interval_ms,
            timeout_s: @default_timeout_s,
            allowed_updates: nil,
            receive_timeout_ms: 10_000,
            fetch_fun: nil,
            delete_webhook_fun: nil,
            delete_webhook?: true,
            poll_ref: nil,
            conflict_count: 0,
            consecutive_conflicts: 0,
            last_error: nil,
            last_poll_at: nil,
            last_success_at: nil,
            last_update_count: 0,
            max_consecutive_conflicts: 12,
            stopped_reason: nil,
            stopped?: false

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @doc "Returns diagnostic polling state for dashboards and support commands."
  @spec status(GenServer.server()) :: map()
  def status(server) do
    GenServer.call(server, :status)
  end

  @impl true
  def init(opts) do
    config = Keyword.fetch!(opts, :config)

    state = %__MODULE__{
      token: config.token,
      runtime: Keyword.fetch!(opts, :runtime),
      interval_ms:
        Keyword.get(opts, :interval_ms, Map.get(config, :poll_interval_ms, @default_interval_ms)),
      timeout_s:
        Keyword.get(opts, :timeout_s, Map.get(config, :poll_timeout_s, @default_timeout_s)),
      allowed_updates: Keyword.get(opts, :allowed_updates),
      receive_timeout_ms:
        Keyword.get(opts, :receive_timeout_ms, Map.get(config, :poll_receive_timeout_ms, 10_000)),
      max_consecutive_conflicts:
        Keyword.get(
          opts,
          :max_consecutive_conflicts,
          Map.get(config, :poll_max_consecutive_conflicts, 12)
        ),
      fetch_fun: Keyword.get(opts, :fetch_fun, &ExGram.get_updates!/1),
      delete_webhook_fun: Keyword.get(opts, :delete_webhook_fun, &ExGram.delete_webhook/1),
      delete_webhook?: Keyword.get(opts, :delete_webhook?, true)
    }

    if state.delete_webhook?, do: state.delete_webhook_fun.(token: state.token)

    {:ok, schedule_poll(state, 0)}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, status_map(state), state}
  end

  @impl true
  def handle_info({:poll, ref}, %{poll_ref: ref, stopped?: false} = state) do
    state = poll(%{state | poll_ref: nil})
    {:noreply, schedule_poll(state, next_interval_ms(state))}
  end

  def handle_info({:poll, _stale_ref}, state), do: {:noreply, state}

  def handle_info(:poll, %{stopped?: false} = state) do
    state = poll(state)
    {:noreply, schedule_poll(state, next_interval_ms(state))}
  end

  def handle_info(:poll, state), do: {:noreply, state}

  defp poll(state) do
    started_at = DateTime.utc_now()
    result = fetch_updates(state)

    case result do
      {:ok, updates} ->
        Enum.each(updates, &Runtime.submit(state.runtime, &1))

        %{
          state
          | offset: next_offset(state.offset, updates),
            consecutive_conflicts: 0,
            last_error: nil,
            last_poll_at: started_at,
            last_success_at: DateTime.utc_now(),
            last_update_count: length(updates)
        }

      {:error, %{kind: :conflict} = error} ->
        conflicts = state.consecutive_conflicts + 1

        state
        |> record_error(error, started_at,
          conflict_count: state.conflict_count + 1,
          consecutive_conflicts: conflicts
        )
        |> maybe_stop_after_conflicts()

      {:error, error} ->
        record_error(state, error, started_at, consecutive_conflicts: 0)
    end
  end

  defp fetch_updates(state) do
    updates =
      state
      |> request_opts()
      |> state.fetch_fun.()

    {:ok, updates}
  rescue
    error ->
      message = Exception.message(error)
      Logger.warning("Telegram polling failed: #{message}")
      {:error, %{kind: classify_error(message), message: message}}
  end

  defp schedule_poll(%{stopped?: true} = state, _interval_ms), do: state

  defp schedule_poll(state, interval_ms) do
    ref = make_ref()
    Process.send_after(self(), {:poll, ref}, interval_ms)
    %{state | poll_ref: ref}
  end

  defp next_interval_ms(%{consecutive_conflicts: conflicts} = state) when conflicts > 0 do
    min((state.interval_ms * :math.pow(2, min(conflicts, 5))) |> round(), 30_000)
  end

  defp next_interval_ms(state), do: state.interval_ms

  defp record_error(state, error, started_at, updates) do
    state
    |> struct!(updates)
    |> Map.merge(%{
      last_error: error,
      last_poll_at: started_at,
      last_update_count: 0
    })
  end

  defp maybe_stop_after_conflicts(state) do
    if state.consecutive_conflicts >= state.max_consecutive_conflicts do
      Logger.warning(
        "Telegram polling stopped after #{state.consecutive_conflicts} consecutive getUpdates conflicts"
      )

      %{state | stopped?: true, stopped_reason: :too_many_conflicts, poll_ref: nil}
    else
      state
    end
  end

  defp classify_error(message) do
    if String.contains?(message, "terminated by other getUpdates request"),
      do: :conflict,
      else: :error
  end

  defp status_map(state) do
    %{
      offset: state.offset,
      timeout_s: state.timeout_s,
      receive_timeout_ms: state.receive_timeout_ms,
      interval_ms: state.interval_ms,
      conflict_count: state.conflict_count,
      consecutive_conflicts: state.consecutive_conflicts,
      last_error: state.last_error,
      last_poll_at: state.last_poll_at,
      last_success_at: state.last_success_at,
      last_update_count: state.last_update_count,
      max_consecutive_conflicts: state.max_consecutive_conflicts,
      stopped_reason: state.stopped_reason,
      stopped?: state.stopped?,
      polling?: state.poll_ref != nil
    }
  end

  defp request_opts(state) do
    [
      token: state.token,
      offset: state.offset,
      timeout: state.timeout_s,
      receive_timeout: state.receive_timeout_ms
    ]
    |> maybe_put_allowed_updates(state.allowed_updates)
  end

  defp maybe_put_allowed_updates(opts, nil), do: opts

  defp maybe_put_allowed_updates(opts, allowed_updates),
    do: Keyword.put(opts, :allowed_updates, allowed_updates)

  defp next_offset(offset, []), do: offset

  defp next_offset(offset, updates) do
    updates
    |> Enum.map(&update_id/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&(&1 + 1))
    |> Enum.reduce(offset, &max/2)
  end

  defp update_id(%{update_id: update_id}), do: update_id
  defp update_id(%{"update_id" => update_id}), do: update_id
  defp update_id(_update), do: nil
end
