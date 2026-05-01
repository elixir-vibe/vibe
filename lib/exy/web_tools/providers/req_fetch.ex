defmodule Exy.WebTools.Providers.ReqFetch do
  @moduledoc """
  Local `Req`-based implementation of `Exy.WebTools.FetchProvider`.
  """

  @behaviour Exy.WebTools.FetchProvider

  alias Exy.WebTools.{FetchResult, HTML}

  @max_response_size 5 * 1024 * 1024
  @max_output_chars 20_000
  @default_timeout_ms 30_000
  @max_timeout_ms 120_000

  @impl true
  def capabilities do
    %{
      formats: [:markdown, :text, :html, :json],
      selectors: true,
      custom_headers: true,
      redirects: true,
      pdf: false,
      max_response_size: @max_response_size,
      max_output_chars: @max_output_chars
    }
  end

  @impl true
  def fetch(url, opts) when is_binary(url) and is_list(opts) do
    with :ok <- validate_url(url) do
      timeout = opts |> Keyword.get(:timeout, @default_timeout_ms) |> normalize_timeout()
      format = opts |> Keyword.get(:format, :markdown) |> normalize_format()
      headers = request_headers(format, Keyword.get(opts, :headers, %{}))

      Req.get(
        url,
        Keyword.merge(Keyword.get(opts, :req_options, []),
          headers: headers,
          redirect: true,
          receive_timeout: timeout
        )
      )
      |> handle_response(url, format, opts)
    end
  end

  defp handle_response({:ok, %{status: status} = response}, url, format, opts)
       when status in 200..299 do
    content_type = content_type(response)
    body = normalize_body(response.body, content_type)
    size = byte_size(body)

    cond do
      size > @max_response_size ->
        {:error, {:response_too_large, size}}

      pdf?(content_type, url) ->
        {:error, :pdf_fetch_not_supported}

      true ->
        build_result(response, url, body, content_type, format, opts)
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}, _url, _format, _opts) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}, _url, _format, _opts), do: {:error, reason}

  defp build_result(response, url, body, content_type, format, opts) do
    final_url = response_url(response) || url
    redirected? = final_url != url

    with {:ok, selected, selector} <-
           maybe_select(body, content_type, Keyword.get(opts, :selector)),
         {:ok, converted, actual_format} <- convert(selected, content_type, format) do
      {text, truncated?, total_chars} = truncate(converted)

      {:ok,
       %FetchResult{
         url: url,
         final_url: final_url,
         provider: :req,
         status: response.status,
         content_type: content_type,
         format: actual_format,
         text: text,
         size_bytes: byte_size(body),
         total_chars: total_chars,
         truncated?: truncated?,
         redirected?: redirected?,
         selector: selector,
         metadata: %{}
       }}
    end
  end

  defp maybe_select(body, _content_type, nil), do: {:ok, body, nil}
  defp maybe_select(body, _content_type, ""), do: {:ok, body, nil}

  defp maybe_select(body, content_type, selector) do
    if html?(content_type) do
      with {:ok, selected} <- HTML.select_html(body, selector) do
        {:ok, selected, selector}
      end
    else
      {:ok, body, nil}
    end
  end

  defp convert(body, _content_type, :json) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, Jason.encode!(decoded, pretty: true), :json}
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  defp convert(body, content_type, :markdown) do
    cond do
      json?(content_type) ->
        convert(body, content_type, :json)

      html?(content_type) ->
        with {:ok, markdown} <- HTML.to_markdown(body), do: {:ok, markdown, :markdown}

      true ->
        {:ok, body, :markdown}
    end
  end

  defp convert(body, content_type, :text) do
    if html?(content_type) do
      with {:ok, text} <- HTML.to_text(body), do: {:ok, text, :text}
    else
      {:ok, body, :text}
    end
  end

  defp convert(body, _content_type, :html), do: {:ok, body, :html}

  defp truncate(text) do
    total_chars = String.length(text)

    if total_chars <= @max_output_chars do
      {text, false, total_chars}
    else
      {String.slice(text, 0, @max_output_chars) <>
         "\n\n[Truncated: #{total_chars - @max_output_chars} chars omitted]", true, total_chars}
    end
  end

  defp validate_url(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) -> :ok
      _uri -> {:error, :invalid_url}
    end
  end

  defp normalize_timeout(timeout) when is_integer(timeout), do: min(timeout, @max_timeout_ms)

  defp normalize_timeout(timeout) when is_float(timeout),
    do: timeout |> trunc() |> normalize_timeout()

  defp normalize_timeout(_timeout), do: @default_timeout_ms

  defp normalize_format(format) when format in [:markdown, :text, :html, :json], do: format

  defp normalize_format(format) when format in ["markdown", "text", "html", "json"],
    do: String.to_existing_atom(format)

  defp normalize_format(_format), do: :markdown

  defp request_headers(format, custom_headers) do
    %{
      "user-agent" => "Exy/#{Application.spec(:exy, :vsn) || "dev"}",
      "accept" => accept_header(format),
      "accept-language" => "en-US,en;q=0.9"
    }
    |> Map.merge(normalize_headers(custom_headers))
  end

  defp normalize_headers(headers) when is_map(headers),
    do: Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)

  defp normalize_headers(headers) when is_list(headers),
    do: Map.new(headers, fn {key, value} -> {to_string(key), to_string(value)} end)

  defp normalize_headers(_headers), do: %{}

  defp accept_header(:markdown),
    do: "text/markdown;q=1.0, text/plain;q=0.8, text/html;q=0.7, */*;q=0.1"

  defp accept_header(:text), do: "text/plain;q=1.0, text/html;q=0.8, */*;q=0.1"
  defp accept_header(:html), do: "text/html;q=1.0, application/xhtml+xml;q=0.9, */*;q=0.1"
  defp accept_header(:json), do: "application/json;q=1.0, */*;q=0.1"

  defp normalize_body(nil, _content_type), do: ""
  defp normalize_body(body, _content_type) when is_binary(body), do: body
  defp normalize_body(body, _content_type), do: Jason.encode!(body)

  defp content_type(response) do
    response.headers
    |> Map.get("content-type", [""])
    |> List.wrap()
    |> List.first()
    |> to_string()
  end

  defp response_url(response) do
    response
    |> Map.get(:request)
    |> case do
      %{url: url} -> URI.to_string(url)
      _ -> nil
    end
  end

  defp html?(content_type), do: String.contains?(content_type, "text/html")

  defp json?(content_type),
    do:
      String.contains?(content_type, "application/json") or
        String.contains?(content_type, "+json")

  defp pdf?(content_type, url),
    do:
      String.contains?(content_type, "application/pdf") or
        String.ends_with?(String.downcase(url), ".pdf")
end
