defmodule Exy.Remote.Session do
  @moduledoc false

  @spec list() :: {:ok, [map()]} | {:error, term()}
  def list, do: call(Exy.Session, :list, [])

  @spec active_count() :: non_neg_integer() | {:badrpc, term()} | {:error, term()}
  def active_count, do: call(Exy.Session, :active_count, [])

  @spec start(keyword()) :: {:ok, map()} | {:error, term()}
  def start(opts) do
    with {:ok, pid} <- call(Exy.Session, :start, [opts]) do
      {:ok, %{id: Exy.Session.state(pid).session_id}}
    end
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, term()}
  def lookup(session_id), do: call(Exy.Session, :lookup, [session_id])

  @spec send_prompt(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_prompt(session_id, text) do
    with {:ok, pid} <- lookup(session_id),
         :ok <-
           Exy.Session.dispatch(pid, %Exy.UI.Command{type: :submit_prompt, data: %{text: text}}) do
      {:ok, %{sent: true, session_id: session_id}}
    end
  end

  defp call(module, function, args) do
    with {:ok, node} <- Exy.Remote.connect() do
      :rpc.call(node, module, function, args)
    end
  end
end
