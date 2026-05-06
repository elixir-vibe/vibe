defmodule Vibe.Model.ErrorTest do
  use ExUnit.Case, async: true

  alias ReqLLM.Error.API.Request
  alias Vibe.Model.Error

  test "normalizes Codex OAuth failures" do
    reason =
      "Failed to build OpenAI Codex streaming request: Invalid parameter: OAuth mode requires :access_token or an oauth file. Looked for oauth.json and auth.json"

    error =
      {:failed, :error,
       {:http_streaming_failed, {:provider_build_failed, %Request{reason: reason, class: :api}}}}

    assert %Vibe.UI.Error{} = normalized = Error.normalize(error)
    assert normalized.kind == :auth_required
    assert normalized.provider == :openai_codex
    assert normalized.message == "Codex sign-in required."
    assert normalized.hint == "Run `vibe --login codex`, then retry."
    assert normalized.retryable?
    assert normalized.detail =~ "OAuth mode requires"
  end

  test "keeps unknown request reasons readable" do
    assert Error.normalize(%Request{reason: "missing token", class: :api}).message ==
             "missing token"
  end

  test "normalizes prompt runner exceptions without parsing formatted strings" do
    error =
      try do
        raise ArgumentError, "boom"
      rescue
        exception -> Error.normalize({:exception, :error, exception, __STACKTRACE__})
      end

    assert error.kind == :prompt_exception
    assert error.message == "ArgumentError: boom"
    assert error.detail =~ "ArgumentError"
    assert error.detail =~ "boom"
  end
end
