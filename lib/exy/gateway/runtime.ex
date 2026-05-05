defmodule Exy.Gateway.Runtime do
  @moduledoc """
  Generic runtime for external chat gateways.

  The runtime receives platform updates from an inbound transport, asks the
  configured backend to normalize and authorize them, then dispatches accepted
  messages into Exy sessions using deterministic gateway session keys.
  """

  use GenServer

  alias Exy.Gateway.{Dispatcher, Message}

  require Logger

  @type dispatch_fun :: (Message.t(), keyword() -> {:ok, String.t()} | {:error, term()})

  defstruct backend: nil,
            config: nil,
            dispatch_fun: &Dispatcher.dispatch/2,
            dispatch_opts: [],
            accepted: 0,
            ignored: 0,
            rejected: 0,
            failed: 0

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {server_opts, init_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @spec submit(GenServer.server(), term()) :: :ok
  def submit(server, update), do: GenServer.cast(server, {:update, update})

  @spec stats(GenServer.server()) :: map()
  def stats(server), do: GenServer.call(server, :stats)

  @impl true
  def init(opts) do
    backend = Keyword.fetch!(opts, :backend)

    config =
      case Keyword.fetch(opts, :config) do
        {:ok, config} -> config
        :error -> load_config!(backend, Keyword.get(opts, :backend_opts, []))
      end

    {:ok,
     %__MODULE__{
       backend: backend,
       config: config,
       dispatch_fun: Keyword.get(opts, :dispatch_fun, &Dispatcher.dispatch/2),
       dispatch_opts: Keyword.get(opts, :dispatch_opts, [])
     }}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply,
     %{
       accepted: state.accepted,
       ignored: state.ignored,
       rejected: state.rejected,
       failed: state.failed
     }, state}
  end

  @impl true
  def handle_cast({:update, update}, state) do
    {:noreply, process_update(update, state)}
  end

  defp process_update(update, state) do
    case state.backend.normalize(update, state.config) do
      {:ok, %{message: %Message{} = message, trigger: trigger}} ->
        maybe_dispatch(message, trigger, state)

      :ignore ->
        %{state | ignored: state.ignored + 1}

      {:error, reason} ->
        Logger.debug("gateway update normalization failed: #{inspect(reason)}")
        %{state | failed: state.failed + 1}
    end
  end

  defp maybe_dispatch(message, trigger, state) do
    if state.backend.authorized?(message, trigger, state.config) do
      case state.dispatch_fun.(message, state.dispatch_opts) do
        {:ok, _session_id} -> %{state | accepted: state.accepted + 1}
        {:error, reason} -> dispatch_failed(state, reason)
      end
    else
      %{state | rejected: state.rejected + 1}
    end
  end

  defp dispatch_failed(state, reason) do
    Logger.debug("gateway message dispatch failed: #{inspect(reason)}")
    %{state | failed: state.failed + 1}
  end

  defp load_config!(backend, opts) do
    case backend.load_config(opts) do
      {:ok, config} -> config
      {:error, reason} -> raise ArgumentError, "gateway config failed: #{inspect(reason)}"
    end
  end
end
