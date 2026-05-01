defmodule Exy.WebToolsTest do
  use ExUnit.Case, async: true

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
             Exy.WebTools.fetch("https://example.test/page",
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

  test "fetch formats json" do
    stub = {__MODULE__, :json_fetch}

    Req.Test.stub(stub, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Req.Test.json(%{ok: true})
    end)

    assert {:ok, result} =
             Exy.WebTools.fetch("https://example.test/api",
               format: :json,
               req_options: [plug: {Req.Test, stub}]
             )

    assert result.format == :json
    assert result.text =~ ~s("ok": true)
  end

  test "fetch validates URLs" do
    assert {:error, :invalid_url} = Exy.WebTools.fetch("file:///etc/passwd")
  end

  test "search provider can be configured per call" do
    defmodule SearchProvider do
      @behaviour Exy.WebTools.SearchProvider

      @impl true
      def search(query, _opts) do
        {:ok,
         %Exy.WebTools.SearchResult{
           query: query,
           provider: :test,
           results: [
             %Exy.WebTools.SearchItem{title: "Result", url: "https://example.test", text: "Body"}
           ]
         }}
      end
    end

    assert {:ok, result} = Exy.WebTools.search("query", provider: SearchProvider)
    assert result.provider == :test
    assert [%{title: "Result"}] = result.results
  end

  test "search and fetch results render through markdown protocol" do
    search = %Exy.WebTools.SearchResult{
      query: "ecto",
      provider: :test,
      results: [
        %Exy.WebTools.SearchItem{title: "Ecto", url: "https://hexdocs.pm/ecto", summary: "Docs"}
      ]
    }

    fetch = %Exy.WebTools.FetchResult{
      url: "https://hexdocs.pm/ecto",
      provider: :req,
      status: 200,
      content_type: "text/markdown",
      format: :markdown,
      text: "# Ecto",
      total_chars: 6
    }

    assert Exy.Markdown.to_markdown(search) =~ "## Web search: ecto"
    assert Exy.Markdown.to_markdown(fetch) =~ "# Ecto"
  end
end
