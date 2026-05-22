defmodule Vibe.UI.Reducer.RestoredPayloadTest do
  use ExUnit.Case, async: true

  alias Vibe.UI.Reducer.RestoredPayload

  test "restores user messages from string-keyed storage payloads" do
    assert RestoredPayload.user_message(%{"text" => "hello", "image_count" => 2}) == %{
             text: "hello",
             image_count: 2
           }
  end

  test "restores typed user messages without nil fields" do
    payload = %Vibe.Event.Message.UserAdded{text: "hello", content: nil, image_count: nil}

    assert RestoredPayload.user_message(payload) == %{text: "hello"}
  end

  test "restores assistant abort defaults" do
    assert RestoredPayload.assistant_abort(%{}) == %{reason: "Cancelled.", notify?: true}

    assert RestoredPayload.assistant_abort(%{"reason" => "stopped", "notify?" => false}) == %{
             reason: "stopped",
             notify?: false
           }
  end

  test "restores named plugin payload shapes" do
    assert RestoredPayload.plugin_status(%{"key" => :web, "text" => "ready"}) == %{
             key: :web,
             text: "ready"
           }
  end

  test "restores context compaction defaults" do
    assert RestoredPayload.context_tokens_before(%{}) == 0
    assert RestoredPayload.context_failure_reason(%{}) == "context compaction failed"
    assert RestoredPayload.context_summary(%{}) == "context compacted"
  end
end
