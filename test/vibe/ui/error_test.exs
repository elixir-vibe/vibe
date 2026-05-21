defmodule Vibe.UI.ErrorTest do
  use ExUnit.Case, async: true

  alias Vibe.UI.Error

  test "error JSON projection stays explicit" do
    error = Error.new("boom", kind: :model, retryable?: true)

    assert Vibe.JSON.Encode.value(error) == %{
             "kind" => "model",
             "message" => "boom",
             "hint" => nil,
             "detail" => nil,
             "provider" => nil,
             "retryable?" => true
           }
  end

  test "semantic UI errors are not directly JSON encodable" do
    assert_raise Protocol.UndefinedError, fn ->
      Jason.encode!(Error.new("boom"))
    end
  end
end
