defmodule Exy.Gateway.Telegram.Backend do
  @moduledoc """
  Telegram implementation of the generic gateway backend contract.

  The backend ties together Telegram config, update normalization, authorization,
  and outbound adapter selection while keeping ExGram and Bot API semantics out
  of the generic gateway runtime.
  """

  @behaviour Exy.Gateway.Backend

  alias Exy.Gateway.Message
  alias Exy.Gateway.Telegram.{Adapter, Authorization, Config, Update}

  @impl true
  def load_config(opts), do: Config.load(opts)

  @impl true
  def normalize(update, %Config{} = config) do
    Update.normalize(update,
      bot_id: Map.get(config, :bot_id),
      bot_username: Map.get(config, :bot_username)
    )
  end

  @impl true
  def authorized?(%Message{} = message, trigger, %Config{} = config) do
    Authorization.authorized?(message.source, config) and
      Authorization.trigger_allowed?(message.source, trigger, config)
  end

  @impl true
  def outbound_adapter(%Config{}), do: Adapter

  @impl true
  def child_specs(%Config{}, _runtime), do: []
end
