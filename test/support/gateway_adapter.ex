defmodule Exy.Test.GatewayAdapter do
  @moduledoc false

  @behaviour Exy.Gateway.Adapter

  @impl true
  def send(chat_id, text, opts) do
    owner = Keyword.fetch!(opts, :owner)
    message_id = "msg-#{System.unique_integer([:positive])}"
    send(owner, {:gateway_send, chat_id, message_id, text, opts})
    {:ok, message_id}
  end

  @impl true
  def edit(chat_id, message_id, text, opts) do
    owner = Keyword.fetch!(opts, :owner)
    send(owner, {:gateway_edit, chat_id, message_id, text, opts})
    {:ok, message_id}
  end

  @impl true
  def delete(_chat_id, _message_id, _opts), do: :ok

  @impl true
  def typing(_chat_id, _opts), do: :ok
end
