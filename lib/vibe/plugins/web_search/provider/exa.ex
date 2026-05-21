defmodule Vibe.Plugins.WebSearch.Provider.Exa do
  @moduledoc """
  Exa-backed implementation of `Vibe.Plugins.WebSearch.SearchProvider`.
  """

  @behaviour Vibe.Plugins.WebSearch.SearchProvider

  alias Vibe.Plugins.WebSearch.{SearchItem, SearchResult}

  @endpoint "https://api.exa.ai/search"
  @default_timeout_ms 30_000
  @default_context_max_characters 10_000
  @highlight_max_characters 2_000
  @restricted_categories MapSet.new([
                           "company",
                           "people",
                           "tweet",
                           "news",
                           "personal site",
                           "financial report"
                         ])

  @impl true
  def capabilities do
    %{
      search_types: [:auto, :instant, :fast, :deep, :neural],
      categories: [
        :company,
        :research_paper,
        :news,
        :tweet,
        :people,
        :personal_site,
        :financial_report
      ],
      filters: [:include_domains, :exclude_domains, :include_text, :exclude_text, :published_date],
      contents: [:text, :highlights, :summary],
      freshness: true
    }
  end

  @impl true
  def search(query, opts) when is_binary(query) and is_list(opts) do
    with {:ok, api_key} <- api_key() do
      started = System.monotonic_time(:millisecond)
      body = search_body(query, opts)

      Req.post(endpoint(),
        json: body,
        auth: {:bearer, api_key},
        receive_timeout: opt(opts, :timeout, @default_timeout_ms),
        retry: :safe_transient
      )
      |> case do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          {:ok,
           %SearchResult{
             query: query,
             provider: :exa,
             results: parse_results(body),
             raw: body,
             metadata: %{elapsed_ms: System.monotonic_time(:millisecond) - started, request: body}
           }}

        {:ok, %{status: status, body: body}} ->
          {:error, %{provider: :exa, status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp search_body(query, opts) do
    num_results = opts |> opt(:num_results, 8) |> min(100)
    context_max = opt(opts, :context_max_characters, @default_context_max_characters)
    category = opt(opts, :category)
    restricted? = category && MapSet.member?(@restricted_categories, to_string(category))

    %{
      query: query,
      numResults: num_results,
      type: opts |> opt(:type, :auto) |> to_string(),
      text: %{maxCharacters: context_max}
    }
    |> put_if(:additionalQueries, opt(opts, :additional_queries))
    |> put_if(:category, normalize_category(category))
    |> put_if(:userLocation, opt(opts, :user_location))
    |> put_if(
      :highlights,
      if(opt(opts, :highlights), do: %{maxCharacters: @highlight_max_characters})
    )
    |> put_if(:summary, if(opt(opts, :summary), do: true))
    |> put_if(:maxAgeHours, opt(opts, :max_age_hours))
    |> maybe_put_filters(opts, restricted?)
  end

  defp maybe_put_filters(body, opts, true) do
    put_if(body, :includeDomains, opt(opts, :include_domains))
  end

  defp maybe_put_filters(body, opts, _restricted?) do
    body
    |> put_if(:includeDomains, opt(opts, :include_domains))
    |> put_if(:excludeDomains, opt(opts, :exclude_domains))
    |> put_if(:includeText, opt(opts, :include_text))
    |> put_if(:excludeText, opt(opts, :exclude_text))
    |> put_if(:startPublishedDate, opt(opts, :start_published_date))
    |> put_if(:endPublishedDate, opt(opts, :end_published_date))
  end

  defp parse_results(%{"results" => results}) when is_list(results) do
    Enum.map(results, fn result ->
      %SearchItem{
        title: result["title"] || "Untitled",
        url: result["url"],
        author: result["author"],
        published_at: result["publishedDate"],
        text: result["text"] || "",
        highlights: result["highlights"] || [],
        summary: result["summary"],
        score: result["score"],
        metadata:
          Map.drop(result, [
            "title",
            "url",
            "author",
            "publishedDate",
            "text",
            "highlights",
            "summary",
            "score"
          ])
      }
    end)
  end

  defp parse_results(_body), do: []

  defp opt(opts, key, default \\ nil) do
    Keyword.get(opts, key, Keyword.get(opts, camel_key(key), default))
  end

  defp camel_key(:num_results), do: :numResults
  defp camel_key(:additional_queries), do: :additionalQueries
  defp camel_key(:context_max_characters), do: :contextMaxCharacters
  defp camel_key(:user_location), do: :userLocation
  defp camel_key(:max_age_hours), do: :maxAgeHours
  defp camel_key(:include_domains), do: :includeDomains
  defp camel_key(:exclude_domains), do: :excludeDomains
  defp camel_key(:include_text), do: :includeText
  defp camel_key(:exclude_text), do: :excludeText
  defp camel_key(:start_published_date), do: :startPublishedDate
  defp camel_key(:end_published_date), do: :endPublishedDate
  defp camel_key(key), do: key

  defp normalize_category(nil), do: nil
  defp normalize_category(category), do: category |> to_string() |> String.replace("_", " ")

  defp api_key do
    case System.get_env("EXA_API_KEY") do
      nil -> {:error, :missing_exa_api_key}
      "" -> {:error, :missing_exa_api_key}
      key -> {:ok, key}
    end
  end

  defp endpoint, do: System.get_env("EXA_ENDPOINT_URL") || @endpoint

  defp put_if(map, _key, nil), do: map
  defp put_if(map, _key, []), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
