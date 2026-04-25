defmodule Exy.Session.PreviewTest do
  use ExUnit.Case, async: true

  test "extracts readable output and content previews" do
    assert Exy.Session.Preview.message(%{result: %{output: "hello\nworld"}}) == "hello world"

    assert Exy.Session.Preview.message(%{
             result: %{message: %{content: [%{type: :text, text: "streamed hello"}]}}
           }) == "streamed hello"
  end

  test "summarizes nested provider failures" do
    error = %ReqLLM.Error.API.Request{reason: "missing token", class: :api}

    assert Exy.Session.Preview.message(%{
             error: {:failed, :error, {:http_streaming_failed, {:provider_build_failed, error}}}
           }) == "ERROR missing token"

    assert Exy.Session.Preview.message(%{
             error: "{:failed, :error, %ReqLLM.Error.API.Request{reason: \"missing token\"}}"
           }) == "ERROR missing token"
  end
end
