defmodule Exy.Session.Store.Summary do
  @moduledoc false

  alias Exy.Session.Store.Listing
  alias Exy.Storage.Schema.Session

  @spec refresh(String.t()) :: :ok
  def refresh(session_id) do
    case Listing.summary(session_id) do
      nil -> update_empty(session_id)
      summary -> update_summary(session_id, summary)
    end
  end

  defp update_empty(session_id) do
    case Exy.Repo.get(Session, session_id) do
      nil ->
        :ok

      session ->
        session |> Ecto.Changeset.change(%{message_count: 0}) |> Exy.Repo.update!() |> ok()
    end
  end

  defp update_summary(session_id, summary) do
    session = Exy.Repo.get!(Session, session_id)

    session
    |> Ecto.Changeset.change(%{
      status: to_string(summary.status || :idle),
      model: summary.model,
      message_count: summary.message_count,
      first_message_preview: summary.first_message,
      last_message_preview: summary.last_message_preview,
      usage_input_tokens: get_in(summary.usage, [:input_tokens]) || 0,
      usage_output_tokens: get_in(summary.usage, [:output_tokens]) || 0,
      usage_total_tokens: get_in(summary.usage, [:total_tokens]) || 0,
      usage_total_cost: get_in(summary.usage, [:total_cost]) || 0.0
    })
    |> Exy.Repo.update!()
    |> ok()
  end

  defp ok(_result), do: :ok
end
