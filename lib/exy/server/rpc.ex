defmodule Exy.Server.RPC do
  @moduledoc false

  alias Exy.UI.Command

  @spec ping() :: :pong
  def ping, do: :pong

  @spec sessions() :: {:ok, [map()]}
  def sessions, do: {:ok, Exy.Sessions.list()}

  @spec active_session_count() :: non_neg_integer()
  def active_session_count, do: Exy.Sessions.active_count()

  @spec new_session(keyword()) :: {:ok, map()} | {:error, term()}
  def new_session(opts \\ []) do
    case Exy.Sessions.start(opts) do
      {:ok, pid} -> {:ok, %{id: Exy.Session.state(pid).session_id}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec session_pid(String.t()) :: {:ok, pid()} | {:error, term()}
  def session_pid(session_id), do: Exy.Sessions.lookup(session_id)

  @spec send_prompt(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_prompt(session_id, text) when is_binary(text) do
    with {:ok, pid} <- Exy.Sessions.lookup(session_id) do
      :ok = Exy.Session.dispatch(pid, %Command{type: :submit_prompt, data: %{text: text}})
      {:ok, %{sent: true, session_id: session_id}}
    end
  end

  @spec cancel(String.t()) :: {:ok, map()} | {:error, term()}
  def cancel(session_id) do
    with {:ok, pid} <- Exy.Sessions.lookup(session_id) do
      :ok = Exy.Session.dispatch(pid, :cancel_stream)
      {:ok, %{cancelled: true, session_id: session_id}}
    end
  end
end
