defmodule Vibe.Session.PreviewTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Error.API.Request

  test "extracts readable output and content previews" do
    assert Vibe.Session.Preview.message(%{result: %{output: "hello\nworld"}}) == "hello world"

    assert Vibe.Session.Preview.message(%{
             result: %{message: %{content: [%{type: :text, text: "streamed hello"}]}}
           }) == "streamed hello"
  end

  test "summarizes nested provider failures" do
    error = %Request{reason: "missing token", class: :api}

    assert Vibe.Session.Preview.message(%{
             error: {:failed, :error, {:http_streaming_failed, {:provider_build_failed, error}}}
           }) == "ERROR missing token"

    assert Vibe.Session.Preview.message(%{
             error: "{:failed, :error, %ReqLLM.Error.API.Request{reason: \"missing token\"}}"
           }) == "ERROR missing token"
  end
end
