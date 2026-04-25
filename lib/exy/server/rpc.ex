defmodule Exy.Server.RPC do
  @moduledoc false

  alias Exy.UI.Command

  @spec ping() :: :pong
  def ping, do: :pong

  @spec sessions() :: [map()]
  def sessions, do: Exy.Sessions.list()

  @spec new_session(keyword()) :: {:ok, map()} | {:error, term()}
  def new_session(opts \\ []) do
    case Exy.Sessions.start(opts) do
      {:ok, pid} -> {:ok, %{id: Exy.Session.state(pid).session_id, pid: pid}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec session_pid(String.t()) :: {:ok, pid()} | {:error, term()}
  def session_pid(session_id), do: Exy.Sessions.lookup(session_id)

  @spec send_prompt(String.t(), String.t()) :: :ok | {:error, term()}
  def send_prompt(session_id, text) when is_binary(text) do
    with {:ok, pid} <- Exy.Sessions.lookup(session_id) do
      Exy.Session.dispatch(pid, %Command{type: :submit_prompt, data: %{text: text}})
    end
  end

  @spec cancel(String.t()) :: :ok | {:error, term()}
  def cancel(session_id) do
    with {:ok, pid} <- Exy.Sessions.lookup(session_id),
         do: Exy.Session.dispatch(pid, :cancel_stream)
  end
end
