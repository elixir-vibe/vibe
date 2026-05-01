defmodule Exy.WebTools do
  @moduledoc """
  Provider-neutral web search and fetch API exposed to eval as `Web`.

  `Web.search/2` and `Web.fetch/2` keep agent-facing code stable while concrete
  providers handle vendor-specific APIs. Exa is the default search provider; a
  local `Req` implementation is the default fetch provider.
  """

  alias Exy.WebTools.{FetchResult, SearchResult}

  @type search_result :: SearchResult.t()
  @type fetch_result :: FetchResult.t()

  @doc "Searches the web through the configured search provider."
  @spec search(String.t(), keyword()) :: {:ok, SearchResult.t()} | {:error, term()}
  def search(query, opts \\ []) when is_binary(query) and is_list(opts) do
    provider = provider(opts, :provider, :web_search_provider, Exy.WebTools.Providers.Exa)
    provider.search(query, Keyword.delete(opts, :provider))
  end

  @doc "Fetches a URL through the configured fetch provider."
  @spec fetch(String.t(), keyword()) :: {:ok, FetchResult.t()} | {:error, term()}
  def fetch(url, opts \\ []) when is_binary(url) and is_list(opts) do
    provider = provider(opts, :provider, :web_fetch_provider, Exy.WebTools.Providers.ReqFetch)
    provider.fetch(url, Keyword.delete(opts, :provider))
  end

  @doc "Raises on web search errors."
  @spec search!(String.t(), keyword()) :: SearchResult.t()
  def search!(query, opts \\ []) do
    case search(query, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "web search failed: #{inspect(reason)}"
    end
  end

  @doc "Raises on URL fetch errors."
  @spec fetch!(String.t(), keyword()) :: FetchResult.t()
  def fetch!(url, opts \\ []) do
    case fetch(url, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "web fetch failed: #{inspect(reason)}"
    end
  end

  @doc "Filters search results to URLs containing a domain substring."
  @spec filter_domain({:ok, SearchResult.t()} | SearchResult.t(), String.t()) ::
          {:ok, SearchResult.t()} | SearchResult.t()
  def filter_domain({:ok, search}, domain), do: {:ok, filter_domain(search, domain)}

  def filter_domain(%SearchResult{results: results} = search, domain) when is_binary(domain) do
    %{search | results: Enum.filter(results, &String.contains?(&1.url || "", domain))}
  end

  @doc "Keeps at most `count` search results."
  @spec take({:ok, SearchResult.t()} | SearchResult.t(), non_neg_integer()) ::
          {:ok, SearchResult.t()} | SearchResult.t()
  def take({:ok, search}, count), do: {:ok, take(search, count)}

  def take(%SearchResult{results: results} = search, count),
    do: %{search | results: Enum.take(results, count)}

  defp provider(opts, opt_key, config_key, default) do
    opts
    |> Keyword.get(opt_key, Application.get_env(:exy, config_key, default))
    |> normalize_provider()
  end

  defp normalize_provider(:exa), do: Exy.WebTools.Providers.Exa
  defp normalize_provider(:req), do: Exy.WebTools.Providers.ReqFetch
  defp normalize_provider(provider) when is_atom(provider), do: provider
end
