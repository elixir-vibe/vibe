defmodule Exy.Plugins.WebSearch.API do
  @moduledoc """
  Pipeable Exa web search API exposed by the WebSearch plugin.
  """

  alias Exy.Plugins.WebSearch.Result

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

  @type search :: %{query: String.t(), results: [Result.t()], raw: map()}

  @spec search(String.t(), keyword()) :: {:ok, search()} | {:error, term()}
  def search(query, opts \\ []) when is_binary(query) and is_list(opts) do
    with {:ok, api_key} <- api_key() do
      body = search_body(query, opts)

      Req.post(endpoint(),
        json: body,
        auth: {:bearer, api_key},
        receive_timeout: Keyword.get(opts, :timeout, @default_timeout_ms)
      )
      |> case do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          {:ok, %{query: query, results: parse_results(body), raw: body}}

        {:ok, %{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @spec filter_domain({:ok, search()} | search(), String.t()) :: {:ok, search()} | search()
  def filter_domain({:ok, search}, domain), do: {:ok, filter_domain(search, domain)}

  def filter_domain(%{results: results} = search, domain) when is_binary(domain) do
    %{search | results: Enum.filter(results, &String.contains?(&1.url || "", domain))}
  end

  @spec take({:ok, search()} | search(), non_neg_integer()) :: {:ok, search()} | search()
  def take({:ok, search}, count), do: {:ok, take(search, count)}

  def take(%{results: results} = search, count),
    do: %{search | results: Enum.take(results, count)}

  defp search_body(query, opts) do
    num_results = opts |> Keyword.get(:num_results, Keyword.get(opts, :numResults, 8)) |> min(100)
    context_max = Keyword.get(opts, :context_max_characters, @default_context_max_characters)
    category = Keyword.get(opts, :category)
    restricted? = category && MapSet.member?(@restricted_categories, category)

    %{
      query: query,
      numResults: num_results,
      type: Keyword.get(opts, :type, "auto"),
      text: %{maxCharacters: context_max}
    }
    |> put_if(:additionalQueries, Keyword.get(opts, :additional_queries))
    |> put_if(:category, category)
    |> put_if(:userLocation, Keyword.get(opts, :user_location))
    |> put_if(
      :highlights,
      if(Keyword.get(opts, :highlights), do: %{maxCharacters: @highlight_max_characters})
    )
    |> put_if(:summary, if(Keyword.get(opts, :summary), do: true))
    |> put_if(:maxAgeHours, Keyword.get(opts, :max_age_hours))
    |> maybe_put_filters(opts, restricted?)
  end

  defp maybe_put_filters(body, opts, true) do
    put_if(body, :includeDomains, Keyword.get(opts, :include_domains))
  end

  defp maybe_put_filters(body, opts, _restricted?) do
    body
    |> put_if(:includeDomains, Keyword.get(opts, :include_domains))
    |> put_if(:excludeDomains, Keyword.get(opts, :exclude_domains))
    |> put_if(:includeText, Keyword.get(opts, :include_text))
    |> put_if(:excludeText, Keyword.get(opts, :exclude_text))
    |> put_if(:startPublishedDate, Keyword.get(opts, :start_published_date))
    |> put_if(:endPublishedDate, Keyword.get(opts, :end_published_date))
  end

  defp parse_results(%{"results" => results}) when is_list(results) do
    Enum.map(results, fn result ->
      %Result{
        title: result["title"] || "Untitled",
        url: result["url"],
        author: result["author"],
        published_date: result["publishedDate"],
        text: result["text"] || "",
        highlights: result["highlights"] || [],
        summary: result["summary"]
      }
    end)
  end

  defp parse_results(_body), do: []

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
