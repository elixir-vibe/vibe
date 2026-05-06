defmodule Vibe.SystemAlarms.Handler do
  @moduledoc """
  `:alarm_handler` event adapter used by `Vibe.SystemAlarms`.

  The SASL alarm manager uses the legacy `:gen_event` behaviour. This module
  keeps that callback shape isolated and forwards normalized events to the
  supervised Vibe process that records telemetry.
  """

  @behaviour :gen_event

  @impl true
  def init(opts) do
    {:ok, %{owner: Keyword.fetch!(opts, :owner)}}
  end

  @impl true
  def handle_event({:set_alarm, {alarm_id, description}}, state) do
    send(state.owner, {:system_alarm, :set, alarm_id, description})
    {:ok, state}
  end

  def handle_event({:clear_alarm, alarm_id}, state) do
    send(state.owner, {:system_alarm, :clear, alarm_id, nil})
    {:ok, state}
  end

  def handle_event(_event, state), do: {:ok, state}

  @impl true
  def handle_call(_request, state), do: {:ok, :ok, state}

  @impl true
  def handle_info(_message, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  @impl true
  def code_change(_old_vsn, state, _extra), do: {:ok, state}
end
