defmodule Vibe.Plugins.WebSearch do
  @moduledoc "Web search plugin and provider-neutral eval API exposed as `Web`."

  use Vibe.Plugin

  alias Vibe.Plugins.WebSearch.{FetchResult, HTML, SearchResult}

  @type search_result :: SearchResult.t()
  @type fetch_result :: FetchResult.t()

  api(
    name: :web_search,
    module: Vibe.Plugins.WebSearch,
    alias: Web,
    description: "Provider-neutral web search and fetch API for eval sessions",
    examples: [
      "Web.search(\"ecto sqlite fts\") |> MD.doc()",
      "Web.fetch(\"https://hexdocs.pm/ecto\") |> MD.doc()"
    ]
  )

  @guidance """
  Use the `Web` eval alias for web search and fetch. Put network concerns in opts \
  (`provider`, `timeout`, `headers`), transformations in pipes (`Web.select!/2`, \
  `Web.truncate/2`, `Web.filter_domain/2`, `Web.take/2`). Render results with \
  `MD.doc/1`. Parse HTML with `Web.parse_html!/1` and Floki, not regexes.
  """

  @impl true
  def system_prompt(_context, state), do: {@guidance, state}

  @doc "Searches the web through the configured search provider."
  @spec search(String.t(), keyword()) :: {:ok, SearchResult.t()} | {:error, term()}
  def search(query, opts \\ []) when is_binary(query) and is_list(opts) do
    provider =
      provider(opts, :provider, :web_search_provider, Vibe.Plugins.WebSearch.Provider.Exa)

    provider.search(query, Keyword.delete(opts, :provider))
  end

  @doc "Fetches a URL through the configured fetch provider."
  @spec fetch(String.t(), keyword()) :: {:ok, FetchResult.t()} | {:error, term()}
  def fetch(url, opts \\ []) when is_binary(url) and is_list(opts) do
    provider =
      provider(opts, :provider, :web_fetch_provider, Vibe.Plugins.WebSearch.Provider.ReqFetch)

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

  @doc "Parses HTML from a fetch result or binary string with Floki."
  @spec parse_html(FetchResult.t() | String.t()) :: {:ok, HTML.html_tree()} | {:error, term()}
  def parse_html(value), do: HTML.parse(value)

  @doc "Parses HTML from a fetch result or binary string with Floki, raising on failure."
  @spec parse_html!(FetchResult.t() | String.t()) :: HTML.html_tree()
  def parse_html!(value), do: HTML.parse!(value)

  @doc "Extracts matching HTML from a fetched page with a CSS selector."
  @spec select(FetchResult.t(), String.t()) :: {:ok, FetchResult.t()} | {:error, term()}
  def select(%FetchResult{} = result, selector) when is_binary(selector) do
    with {:ok, html} <- HTML.select_html(result, selector) do
      {:ok, update_fetch_text(result, html, format: :html, selector: selector)}
    end
  end

  @doc "Extracts matching HTML from a fetched page with a CSS selector, raising on failure."
  @spec select!(FetchResult.t(), String.t()) :: FetchResult.t()
  def select!(%FetchResult{} = result, selector) do
    case select(result, selector) do
      {:ok, selected} -> selected
      {:error, reason} -> raise "web select failed: #{inspect(reason)}"
    end
  end

  @doc "Truncates fetched content or plain text using the shared tool-output byte limit."
  @spec truncate(FetchResult.t(), keyword() | pos_integer()) :: FetchResult.t()
  @spec truncate(String.t(), keyword() | pos_integer()) :: String.t()
  def truncate(value, opts \\ [])

  def truncate(%FetchResult{} = result, opts) do
    limit = truncate_limit(opts)
    text = result.text || ""
    limited = Vibe.Tool.Output.limit_text(text, limit)

    update_fetch_text(result, limited,
      truncated?: byte_size(limited) != byte_size(text),
      total_chars: String.length(text)
    )
  end

  def truncate(text, opts) when is_binary(text) do
    Vibe.Tool.Output.limit_text(text, truncate_limit(opts))
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

  defp update_fetch_text(%FetchResult{} = result, text, updates) do
    total_chars = Keyword.get(updates, :total_chars, String.length(text))

    result
    |> Map.merge(%{
      text: text,
      total_chars: total_chars,
      truncated?: Keyword.get(updates, :truncated?, false)
    })
    |> maybe_put(:format, Keyword.get(updates, :format))
    |> maybe_put(:selector, Keyword.get(updates, :selector, result.selector))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp truncate_limit(opts) when is_integer(opts), do: normalize_limit(opts)

  defp truncate_limit(opts) when is_list(opts) do
    opts
    |> Keyword.get(:bytes, Keyword.get(opts, :chars, Vibe.Tool.Output.default_max_bytes()))
    |> normalize_limit()
  end

  defp truncate_limit(_opts), do: Vibe.Tool.Output.default_max_bytes()

  defp normalize_limit(limit) when is_integer(limit) and limit > 0, do: limit
  defp normalize_limit(_limit), do: Vibe.Tool.Output.default_max_bytes()

  defp provider(opts, opt_key, config_key, default) do
    opts
    |> Keyword.get(opt_key, Application.get_env(:vibe, config_key, default))
    |> normalize_provider()
  end

  defp normalize_provider(:exa), do: Vibe.Plugins.WebSearch.Provider.Exa
  defp normalize_provider(:req), do: Vibe.Plugins.WebSearch.Provider.ReqFetch
  defp normalize_provider(provider) when is_atom(provider), do: provider
end
