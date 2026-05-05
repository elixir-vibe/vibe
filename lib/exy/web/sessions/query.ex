defmodule Exy.Web.Sessions.Query do
  @moduledoc "Filtering, grouping, and pagination helpers for the sessions page."

  @spec page(String.t() | nil, integer(), pos_integer()) :: map()
  def page(query, requested_page, page_size) do
    filtered = sessions(query)
    total_pages = max(1, ceil_div(length(filtered), page_size))
    page = requested_page |> max(1) |> min(total_pages)
    sessions = Enum.slice(filtered, (page - 1) * page_size, page_size)

    %{
      query: query || "",
      filtered: filtered,
      sessions: sessions,
      groups: group_sessions(sessions, page_size),
      page: page,
      total_pages: total_pages,
      page_start: page_start(length(filtered), page, page_size),
      page_end: min(page * page_size, length(filtered))
    }
  end

  @spec parse_page(String.t() | integer() | term()) :: integer()
  def parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, _rest} -> page
      :error -> 1
    end
  end

  def parse_page(page) when is_integer(page), do: page
  def parse_page(_page), do: 1

  @spec metrics([map()]) :: %{message_total: integer(), token_total: integer()}
  def metrics(sessions) do
    usage = Enum.map(sessions, &(&1.usage || %{}))

    %{
      message_total: Enum.sum(Enum.map(sessions, &(&1.message_count || 0))),
      token_total: Enum.sum(Enum.map(usage, &Map.get(&1, :total_tokens, 0)))
    }
  end

  @spec session_title(map()) :: String.t()
  def session_title(session) do
    Map.get(session, :first_message) || Map.get(session, :last_message_preview) ||
      "Untitled session"
  end

  defp sessions(query) do
    query = String.downcase(String.trim(query || ""))

    Exy.Session.list()
    |> Enum.filter(fn session -> query == "" or session_matches?(session, query) end)
  end

  defp group_sessions(sessions, page_size) do
    {active, inactive} = Enum.split_with(sessions, &Map.get(&1, :live?, false))
    {recent, older} = Enum.split(inactive, page_size)
    %{active: active, recent: recent, older: older}
  end

  defp page_start(0, _page, _page_size), do: 0
  defp page_start(_count, page, page_size), do: (page - 1) * page_size + 1

  defp ceil_div(count, page_size), do: div(count + page_size - 1, page_size)

  defp session_matches?(session, query) do
    [
      session.id,
      session.cwd,
      session.first_message,
      session.last_message_preview,
      session.model,
      session.status
    ]
    |> Enum.map(&to_string/1)
    |> Enum.any?(&(String.downcase(&1) =~ query))
  end
end
