defmodule Exy.Model.TransportTest do
  use ExUnit.Case, async: false

  test "leaves ordinary stream options unchanged" do
    opts = [provider_options: [reasoning_effort: "medium"]]

    assert Exy.Model.Transport.prepare_stream_opts(
             "openrouter:test/model",
             opts,
             "transport-test"
           ) ==
             {:ok, opts}
  end

  test "turns internal reusable websocket policy into provider transport options" do
    model = %LLMDB.Model{id: "example-model", provider: :openrouter}

    assert {:error, {:unsupported_reusable_websocket_provider, :openrouter}} =
             Exy.Model.Transport.prepare_stream_opts(
               model,
               [provider_options: [openai_reuse_websocket: true]],
               "transport-test"
             )
  end
end
