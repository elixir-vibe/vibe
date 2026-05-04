defmodule Exy.CLI.Sessions.Filter do
  @moduledoc "Session list filtering by status, age, and flags."
  @spec apply([map()], keyword()) :: [map()]
  def apply(sessions, opts) do
    sessions
    |> maybe_filter_live(opts[:live])
    |> maybe_filter_failed(opts[:failed])
    |> maybe_filter_useful(opts[:all] || opts[:live] || opts[:failed])
    |> Enum.take(opts[:limit] || if(opts[:all], do: length(sessions), else: 20))
  end

  defp maybe_filter_live(sessions, true), do: Enum.filter(sessions, & &1[:live?])
  defp maybe_filter_live(sessions, _live?), do: sessions

  defp maybe_filter_failed(sessions, true), do: Enum.filter(sessions, &failed?/1)
  defp maybe_filter_failed(sessions, _failed?), do: sessions

  defp maybe_filter_useful(sessions, true), do: sessions

  defp maybe_filter_useful(sessions, _raw?) do
    Enum.filter(sessions, fn session -> session[:live?] or useful?(session) end)
  end

  defp useful?(session) do
    message_count = session[:message_count] || 0
    preview = session[:first_message] || session[:last_message_preview] || ""
    message_count > 0 and preview != "" and not internal_id?(session[:id])
  end

  defp failed?(session) do
    preview = session[:last_message_preview] || ""

    String.contains?(preview, [
      "ERROR",
      "failed",
      "http_streaming_failed",
      "provider_build_failed"
    ])
  end

  defp internal_id?(id) when is_binary(id) do
    String.starts_with?(id, [
      "plugin-",
      "selector-",
      "attach-",
      "durable-",
      "restore-",
      "ui-session",
      "loader-",
      "background-"
    ])
  end

  defp internal_id?(_id), do: false
end
