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
            fetch_fun: nil,
            delete_webhook_fun: nil,
            delete_webhook?: true

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
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
      fetch_fun: Keyword.get(opts, :fetch_fun, &ExGram.get_updates!/1),
      delete_webhook_fun: Keyword.get(opts, :delete_webhook_fun, &ExGram.delete_webhook/1),
      delete_webhook?: Keyword.get(opts, :delete_webhook?, true)
    }

    if state.delete_webhook?, do: state.delete_webhook_fun.(token: state.token)
    send(self(), :poll)

    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = poll(state)
    Process.send_after(self(), :poll, state.interval_ms)
    {:noreply, state}
  end

  defp poll(state) do
    updates = fetch_updates(state)
    Enum.each(updates, &Runtime.submit(state.runtime, &1))
    %{state | offset: next_offset(state.offset, updates)}
  end

  defp fetch_updates(state) do
    state
    |> request_opts()
    |> state.fetch_fun.()
  rescue
    error ->
      Logger.warning("Telegram polling failed: #{Exception.message(error)}")
      []
  end

  defp request_opts(state) do
    [token: state.token, offset: state.offset, timeout: state.timeout_s]
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
