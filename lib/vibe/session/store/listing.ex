defmodule Vibe.Session.Store.Listing do
  @moduledoc "Session listing queries against SQLite storage."
  import Ecto.Query

  alias Vibe.Storage.Schema.Session

  @spec info(String.t()) :: map() | nil
  def info(session_id) when is_binary(session_id) do
    Vibe.Storage.ensure!()

    case Vibe.Repo.get(Session, session_id) do
      %Session{} = session -> session_info(session)
      nil -> nil
    end
  end

  @spec list() :: [map()]
  def list do
    Vibe.Storage.ensure!()

    Session
    |> where([session], session.message_count > 0)
    |> order_by([session], desc: session.updated_at)
    |> Vibe.Repo.all()
    |> Enum.map(&session_info/1)
  end

  @spec summary(String.t()) :: map() | nil
  def summary(session_id), do: Vibe.Session.Store.Summary.summary(session_id) |> listed_summary()

  defp listed_summary(summary), do: summary

  defp session_info(%Session{} = session) do
    %{
      id: session.id,
      path: Vibe.Paths.database() |> Path.expand(),
      size: 0,
      created_at: nil,
      updated_at: session.updated_at,
      cwd: session.cwd,
      message_count: session.message_count || 0,
      first_message: session.first_message_preview,
      last_message_preview: session.last_message_preview,
      status: stored_status(session.status),
      model: session.model,
      usage: %{
        input_tokens: session.usage_input_tokens || 0,
        output_tokens: session.usage_output_tokens || 0,
        total_tokens: session.usage_total_tokens || 0,
        total_cost: session.usage_total_cost || 0.0
      }
    }
  end

  defp stored_status(status) do
    case status_atom(status) do
      status when status in [:working, :running] -> :idle
      status -> status
    end
  end

  defp status_atom(status) when is_binary(status) do
    String.to_existing_atom(status)
  rescue
    ArgumentError -> :idle
  end

  defp status_atom(status) when is_atom(status), do: status
  defp status_atom(_status), do: :idle
end
