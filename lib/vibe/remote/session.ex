defmodule Vibe.Remote.Session do
  @moduledoc "Remote session lifecycle commands over distributed Erlang."

  alias Vibe.UI.Command
  @spec list() :: {:ok, [map()]} | {:error, term()} | {:badrpc, term()}
  def list do
    case call(Vibe.Session, :list, []) do
      sessions when is_list(sessions) -> {:ok, sessions}
      other -> other
    end
  end

  @spec active_count() :: non_neg_integer() | {:badrpc, term()} | {:error, term()}
  def active_count, do: call(Vibe.Session, :active_count, [])

  @spec start(keyword()) :: {:ok, map()} | {:error, term()}
  def start(opts) do
    with {:ok, pid} <- call(Vibe.Session, :start, [opts]) do
      {:ok, %{id: Vibe.Session.state(pid).session_id}}
    end
  end

  @spec lookup(String.t()) :: {:ok, pid()} | {:error, term()}
  def lookup(session_id), do: call(Vibe.Session, :lookup, [session_id])

  @spec send_prompt(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def send_prompt(session_id, text) do
    with {:ok, pid} <- lookup(session_id),
         :ok <-
           Vibe.Session.dispatch(pid, %Command{type: :submit_prompt, data: %{text: text}}) do
      {:ok, %{sent: true, session_id: session_id}}
    end
  end

  defp call(module, function, args) do
    with {:ok, node} <- Vibe.Remote.connect() do
      :rpc.call(node, module, function, args)
    end
  end
end
