defmodule Vibe.WebToolsTest do
  use ExUnit.Case, async: true

  alias Vibe.WebTools.{FetchResult, SearchItem, SearchResult}

  test "fetch converts selected HTML to markdown" do
    stub = {__MODULE__, :html_fetch}

    Req.Test.stub(stub, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "text/html")
      |> Req.Test.html(
        ~s(<html><body><main><h1>Title</h1><p>Hello <strong>web</strong>.</p></main></body></html>)
      )
    end)

    assert {:ok, result} =
             Vibe.WebTools.fetch("https://example.test/page",
               selector: "main",
               format: :markdown,
               req_options: [plug: {Req.Test, stub}]
             )

    assert result.provider == :req
    assert result.format == :markdown
    assert result.selector == "main"
    assert result.text =~ "# Title"
    assert result.text =~ "Hello **web**."
  end

  test "fetch follows redirects and records final URL" do
    stub = {__MODULE__, :redirect_fetch}

    Req.Test.stub(stub, fn conn ->
      case conn.request_path do
        "/redirect" ->
          Req.Test.redirect(conn, to: "/final")

        "/final" ->
          conn
          |> Plug.Conn.put_resp_header("content-type", "text/html")
          |> Req.Test.html(~s(<html><body><h1>Final</h1></body></html>))
      end
    end)

    assert {:ok, result} =
             Vibe.WebTools.fetch("https://example.test/redirect",
               format: :html,
               req_options: [plug: {Req.Test, stub}]
             )

    assert result.redirected?
    assert result.final_url == "https://example.test/final"
    assert result.text =~ "Final"
  end

  test "basic HTML to Markdown converter handles common structure" do
    html = """
    <h1>Title</h1><p>Hello <a href=\"/x\">link</a>.</p><blockquote>Quote</blockquote><ul><li>One</li><li>Two<ul><li>Nested</li></ul></li></ul><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table><pre><code>mix test</code></pre>
    """

    assert {:ok, markdown} = Vibe.WebTools.HTML.to_markdown(html)

    assert markdown ==
             """
             # Title

             Hello [link](/x).

             > Quote

             - One
             - Two
               - Nested

             | A | B |
             | --- | --- |
             | 1 | 2 |

             ```
             mix test
             ```
             """
             |> String.trim()
  end

  test "fetch formats json" do
    stub = {__MODULE__, :json_fetch}

    Req.Test.stub(stub, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Req.Test.json(%{ok: true})
    end)

    assert {:ok, result} =
             Vibe.WebTools.fetch("https://example.test/api",
               format: :json,
               req_options: [plug: {Req.Test, stub}]
             )

    assert result.format == :json
    assert result.text =~ ~s("ok": true)
  end

  test "pipe helpers select, parse, and convert fetched HTML" do
    result = %FetchResult{
      url: "https://example.test/page",
      provider: :req,
      status: 200,
      content_type: "text/html",
      format: :html,
      text:
        ~s(<html><body><main><h1>Title</h1><p>Hello <strong>web</strong>.</p></main></body></html>),
      total_chars: 91
    }

    selected = Vibe.WebTools.select!(result, "main")

    assert selected.format == :html
    assert selected.selector == "main"
    assert selected.text =~ "<main>"
    assert Vibe.WebTools.parse_html!(selected) |> Floki.find("strong") |> Floki.text() == "web"
    assert Vibe.Markdown.to_markdown(selected) =~ "Hello **web**."

    text = selected |> Vibe.WebTools.parse_html!() |> Floki.text(sep: " ")

    assert text =~ "Title"
    assert text =~ "Hello"
    assert text =~ "web"
  end

  test "pipe helper truncates fetched content" do
    result = %FetchResult{text: "abcdef", total_chars: 6}

    truncated = Vibe.WebTools.truncate(result, chars: 3)

    assert truncated.truncated?
    assert truncated.total_chars == 6
    assert truncated.text =~ "abc"
    assert truncated.text =~ "3 chars omitted"
  end

  test "fetch validates URLs" do
    assert {:error, :invalid_url} = Vibe.WebTools.fetch("file:///etc/passwd")
  end

  test "search provider can be configured per call" do
    defmodule SearchProvider do
      @behaviour Vibe.WebTools.SearchProvider

      @impl true
      def search(query, _opts) do
        {:ok,
         %SearchResult{
           query: query,
           provider: :test,
           results: [
             %SearchItem{title: "Result", url: "https://example.test", text: "Body"}
           ]
         }}
      end
    end

    assert {:ok, result} = Vibe.WebTools.search("query", provider: SearchProvider)
    assert result.provider == :test
    assert [%{title: "Result"}] = result.results
  end

  test "search and fetch results render through markdown protocol" do
    search = %SearchResult{
      query: "ecto",
      provider: :test,
      results: [
        %SearchItem{title: "Ecto", url: "https://hexdocs.pm/ecto", summary: "Docs"}
      ]
    }

    fetch = %FetchResult{
      url: "https://hexdocs.pm/ecto",
      provider: :req,
      status: 200,
      content_type: "text/markdown",
      format: :markdown,
      text: "# Ecto",
      total_chars: 6
    }

    assert Vibe.Markdown.to_markdown(search) =~ "## Web search: ecto"
    assert Vibe.Markdown.to_markdown(fetch) =~ "# Ecto"
  end
end
